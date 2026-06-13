#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RouterIp,
    [int]$Port = 22,
    [string]$User = "root",
    [string]$NetworkId,
    [string]$RouterScriptUrl = "https://raw.githubusercontent.com/moz9/zt-router-support-private/main/scripts/openwrt-install-fixed-network.sh"
)

$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Text)
    Write-Host ""
    Write-Host "== $Text ==" -ForegroundColor Cyan
}

function Read-Default {
    param(
        [string]$Prompt,
        [string]$Default
    )

    $value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $Default
    }
    return $value
}

function Invoke-RemoteChecked {
    param(
        [int]$SessionId,
        [string]$Command,
        [int]$TimeOut = 60,
        [switch]$ShowOutput
    )

    $result = Invoke-SSHCommand -SessionId $SessionId -Command $Command -TimeOut $TimeOut

    if ($ShowOutput -and $result.Output) {
        $result.Output | ForEach-Object { Write-Host $_ }
    }
    if ($result.Error) {
        $result.Error | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }

    if ($result.ExitStatus -ne 0) {
        throw "Remote command failed with exit code $($result.ExitStatus): $Command"
    }

    return $result
}

function Send-FileOverSshBase64 {
    param(
        [int]$SessionId,
        [string]$LocalPath,
        [string]$RemotePath
    )

    $bytes = [System.IO.File]::ReadAllBytes($LocalPath)
    $base64 = [System.Convert]::ToBase64String($bytes)
    $remoteBase64 = "$RemotePath.b64"
    $chunkSize = 6000

    Invoke-RemoteChecked -SessionId $SessionId -Command "rm -f '$remoteBase64' '$RemotePath'; umask 077; touch '$remoteBase64'" | Out-Null

    for ($offset = 0; $offset -lt $base64.Length; $offset += $chunkSize) {
        $length = [Math]::Min($chunkSize, $base64.Length - $offset)
        $chunk = $base64.Substring($offset, $length)
        Invoke-RemoteChecked -SessionId $SessionId -Command "printf '%s' '$chunk' >> '$remoteBase64'" | Out-Null
    }

    $decodeCommand = "if command -v base64 >/dev/null 2>&1; then base64 -d '$remoteBase64' > '$RemotePath'; elif command -v busybox >/dev/null 2>&1; then busybox base64 -d '$remoteBase64' > '$RemotePath'; else echo 'base64 decoder not found on router' >&2; exit 1; fi; chmod 700 '$RemotePath'; rm -f '$remoteBase64'"
    Invoke-RemoteChecked -SessionId $SessionId -Command $decodeCommand | Out-Null
}

function Read-NetworkId {
    param([string]$CurrentValue)

    $value = $CurrentValue
    while ([string]::IsNullOrWhiteSpace($value)) {
        $value = Read-Host "ZeroTier Network ID"
    }

    $value = $value.Trim()
    if ($value -notmatch '^[0-9a-fA-F]{16}$') {
        throw "Bad ZeroTier Network ID. It must be 16 hexadecimal characters."
    }

    return $value.ToLowerInvariant()
}

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptDir = $env:TEMP
}
else {
    $scriptDir = Split-Path -Parent $scriptPath
}

$routerScript = Join-Path $scriptDir "openwrt-install-fixed-network.sh"

if (-not (Test-Path $routerScript)) {
    Write-Step "Download OpenWrt installer"
    Invoke-WebRequest -UseBasicParsing -Uri $RouterScriptUrl -OutFile $routerScript
}

if ([string]::IsNullOrWhiteSpace($RouterIp)) {
    $RouterIp = Read-Host "Router IP address, for example 192.168.1.1"
}

$portText = Read-Default -Prompt "SSH port" -Default "$Port"
$Port = [int]$portText
$User = Read-Default -Prompt "SSH username" -Default $User
$NetworkId = Read-NetworkId -CurrentValue $NetworkId
$password = Read-Host "Router password for $User@$RouterIp" -AsSecureString
$credential = [System.Management.Automation.PSCredential]::new($User, $password)

Write-Step "Prepare Windows SSH module"
if (-not (Get-Module -ListAvailable -Name Posh-SSH)) {
    Write-Host "Installing Posh-SSH for the current Windows user..."
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Scope CurrentUser -Force | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name Posh-SSH -Scope CurrentUser -Force -AllowClobber
}
Import-Module Posh-SSH

$sshSession = $null

try {
    Write-Step "Connect to router"
    $sshSession = New-SSHSession -ComputerName $RouterIp -Port $Port -Credential $credential -AcceptKey -KeepAliveInterval 30

    Write-Step "Upload installer to OpenWrt"
    $remoteScript = "/tmp/openwrt-install-fixed-network.sh"
    Send-FileOverSshBase64 -SessionId $sshSession.SessionId -LocalPath $routerScript -RemotePath $remoteScript

    $remoteCommand = "chmod 700 '$remoteScript' && ZRS_NETWORK_ID='$NetworkId' sh '$remoteScript'"

    Write-Step "Install and join ZeroTier network"
    $result = Invoke-SSHCommand -SessionId $sshSession.SessionId -Command $remoteCommand -TimeOut 1800

    if ($result.Output) {
        $result.Output | ForEach-Object { Write-Host $_ }
    }
    if ($result.Error) {
        $result.Error | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }

    if ($result.ExitStatus -ne 0) {
        throw "Remote installer failed with exit code $($result.ExitStatus)."
    }

    Write-Step "Done"
    Write-Host "Send the ZeroTier Node ID above to the support operator."
    Write-Host "The operator must authorize the router in ZeroTier Central before remote access works."
}
finally {
    if ($sshSession) {
        Remove-SSHSession -SessionId $sshSession.SessionId | Out-Null
    }
}
