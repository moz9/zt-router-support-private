# ZeroTier Router Support Kit

Public support kit for installing ZeroTier remote access on OpenWrt routers.

The public version does not include a fixed ZeroTier Network ID. The installer asks for it during setup.

## Files

- `scripts/Install-ZeroTier-Router-Support.cmd` - Windows one-click launcher for users.
- `scripts/README-FOR-USER.txt` - short user-facing explanation to include in the zip.
- `scripts/windows-oneclick-install.ps1` - Windows installer logic.
- `scripts/openwrt-install-fixed-network.sh` - OpenWrt installer uploaded and executed by the Windows script.
- `scripts/openwrt-disable-support.sh` - disables/removes this support network from an OpenWrt router.
- `docs/operator-guide.md` - your working guide and troubleshooting checklist.

## User Flow

Option A: ask the user to open PowerShell and run:

```powershell
$u='https://raw.githubusercontent.com/moz9/zt-router-support-private/main/scripts/windows-oneclick-install.ps1';$f="$env:TEMP\zt-router-install.ps1";Invoke-WebRequest -UseBasicParsing $u -OutFile $f;powershell -NoProfile -ExecutionPolicy Bypass -File $f
```

Option B: send the user the whole `scripts` folder as a zip file. They should read `README-FOR-USER.txt`, unpack it, and double-click:

```text
Install-ZeroTier-Router-Support.cmd
```

They will enter:

- router IP, usually `192.168.1.1`;
- SSH port, usually `22`;
- SSH username, usually `root`;
- ZeroTier Network ID from the support operator;
- router password.

The script installs ZeroTier support on the router, joins the specified ZeroTier network, and prints the router ZeroTier Node ID. It uses plain SSH only; SFTP is not required on the router.

After that, authorize the new member in ZeroTier Central. Then connect to the router LuCI URL shown by the installer.

## Important

This repository is public so users can download the installer directly. The ZeroTier Network ID is not a password, but it lets anyone request to join the support network. Authorize only expected router Node IDs in ZeroTier Central.

Do not collect or store user router passwords. The Windows script prompts locally and uses the password only for the SSH session.
