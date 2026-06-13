# Operator Guide

This guide is for installing and using ZeroTier remote support on customer OpenWrt routers.

The public repository does not contain your support ZeroTier Network ID. Use your current Network ID when the installer asks for it, or build a local/private user package with the ID prefilled.

## Normal Installation

Fast public GitHub method:

Ask the user to open PowerShell and run:

```powershell
$u='https://raw.githubusercontent.com/moz9/zt-router-support-private/main/scripts/windows-oneclick-install.ps1';$f="$env:TEMP\zt-router-install.ps1";Invoke-WebRequest -UseBasicParsing $u -OutFile $f;powershell -NoProfile -ExecutionPolicy Bypass -File $f
```

Zip method:

Send the user a zip containing the `scripts` folder.

Ask them to unpack it and run:

```text
Install-ZeroTier-Router-Support.cmd
```

They enter:

```text
Router IP: 192.168.1.1
SSH port: 22
SSH username: root
ZeroTier Network ID: your support network ID
Router password: their OpenWrt root password
```

The script does this:

- connects to the router over SSH;
- uploads `openwrt-install-fixed-network.sh` over plain SSH/base64, without requiring SFTP;
- creates a backup under `/root/zt-router-support-backups`;
- installs the `moz9/zerotier-router-support` LuCI helper;
- installs ZeroTier if missing;
- joins the ZeroTier Network ID entered during setup;
- opens LuCI/SSH access from the ZeroTier interface;
- prints Node ID, ZeroTier IP, LuCI URL, and SSH example.

## Authorize Router

Open ZeroTier Central and authorize the new member in network:

```text
your support network
```

Recommended member name:

```text
client-name-router-model-city
```

After authorization, wait 10-30 seconds and ask the user to keep the router powered on.

## Connect

Use the ZeroTier IP shown in the installer output or in ZeroTier Central.

LuCI:

```text
http://<ZT-IP>/cgi-bin/luci/
```

SSH:

```sh
ssh root@<ZT-IP>
```

If their Dropbear is not on port `22`, use the shown/custom port:

```sh
ssh -p <PORT> root@<ZT-IP>
```

## Check From Router

If you already have SSH:

```sh
zerotier-cli info
zerotier-cli listnetworks
ip addr show | grep -A3 zt
uci show firewall.zt_support
uci show firewall.allow_zt_support_router
```

Good state usually looks like:

```text
200 info <node-id> <version> ONLINE
200 listnetworks <network-id> <name> ... OK PRIVATE zt... <ip>/24
```

## Common Cases

Wrong router IP:

Ask user to open OpenWrt in browser and use the same IP, usually:

```text
192.168.1.1
192.168.0.1
192.168.31.1
```

Wrong SSH port:

Try:

```text
22
22222
```

Wrong password:

Ask user to log into LuCI with the same root password. If LuCI works but SSH fails, SSH password login may be disabled.

Windows says scripts are blocked:

Run the `.cmd` file, not the `.ps1` file directly. The `.cmd` launcher starts PowerShell with process-local execution bypass.

PowerShell cannot install Posh-SSH:

The Windows machine cannot reach PowerShell Gallery or policy blocks module install. Fallback: run installation manually from any machine with SSH access to the router.

Old installer fails with `New-SFTPSession : Channel was closed`:

This means the router accepts SSH but does not provide SFTP, which is normal on many OpenWrt/Dropbear installs. Use the current installer version from this repository; it uploads over plain SSH and does not use SFTP.

Manual router install:

```sh
wget -O /tmp/openwrt-install-fixed-network.sh https://raw.githubusercontent.com/moz9/zt-router-support-private/main/scripts/openwrt-install-fixed-network.sh
sh /tmp/openwrt-install-fixed-network.sh
```

Since this repo is public, raw GitHub URLs work without GitHub login.

ZeroTier status is `ACCESS_DENIED`:

Authorize the router member in ZeroTier Central.

ZeroTier status is `REQUESTING_CONFIGURATION`:

Usually the member is not authorized yet or the network did not assign an IP. Authorize it, then wait 10-30 seconds.

LuCI opens but SSH does not:

Check Dropbear port and ZeroTier firewall ports:

```sh
uci show dropbear
uci show firewall.allow_zt_support_router
```

Allow the Dropbear port from ZeroTier:

```sh
uci add_list firewall.allow_zt_support_router.dest_port='22222'
uci commit firewall
/etc/init.d/firewall reload
```

Router has internet but ZeroTier stays offline:

Check DNS and time:

```sh
date
nslookup my.zerotier.com
logread | grep -i zerotier
```

Podkop/sing-box affects access:

Make sure the ZeroTier interface is not added as a source interface for proxy routing unless you explicitly want that:

```sh
uci get podkop.settings.source_network_interfaces
uci get podkop.settings.enable_output_network_interface
```

## Disable Support Access

On the router:

```sh
ZRS_NETWORK_ID='<network-id>' sh /tmp/openwrt-disable-support.sh
```

Or manually:

```sh
zerotier-cli leave <network-id>
/etc/init.d/zerotier stop
uci delete firewall.zt_support
uci delete firewall.allow_zt_support_router
uci commit firewall
/etc/init.d/firewall reload
```

Also remove or deauthorize the member in ZeroTier Central.

## Restore Backup

Installer backups are stored here:

```text
/root/zt-router-support-backups
```

Find the latest backup:

```sh
cat /root/zt-router-support-backups/last-backup-path
```

Inspect archive:

```sh
tar -tzf /root/zt-router-support-backups/config-before-zerotier-YYYYMMDD-HHMMSS.tar.gz
```

Restore `/etc/config` files only if needed:

```sh
mkdir -p /tmp/zt-restore
tar -xzf /root/zt-router-support-backups/config-before-zerotier-YYYYMMDD-HHMMSS.tar.gz -C /tmp/zt-restore
cp -pR /tmp/zt-restore/etc-config/. /etc/config/
/etc/init.d/network reload || /etc/init.d/network restart
/etc/init.d/firewall restart
/etc/init.d/dropbear restart
```

## Safety Rules

Always keep at least one working access path while changing customer routers.

Because this repository is public, it must not contain your support Network ID. Treat the Network ID as shareable setup data, not as a password. Do not enable automatic trust for unknown devices. Authorize only the router Node ID that the user just sent you.

Prefer this order:

1. User installs ZeroTier support locally.
2. You authorize the router in ZeroTier Central.
3. You confirm LuCI opens through ZeroTier.
4. You confirm SSH works if needed.
5. Only then change Podkop, firewall, WAN, or routing settings.

Do not hide this access from users. Tell them the router is joining your support ZeroTier network and that they can revoke access by leaving the network or resetting/removing ZeroTier.
