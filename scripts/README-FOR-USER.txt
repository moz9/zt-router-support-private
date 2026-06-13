ZeroTier Router Support Installer
=================================

Run:

  Install-ZeroTier-Router-Support.cmd

You will be asked for:

  1. Router IP address, usually 192.168.1.1
  2. SSH port, usually 22
  3. SSH username, usually root
  4. ZeroTier Network ID from the support operator
  5. Router password

What this installer does:

  - connects to your OpenWrt router over SSH;
  - installs ZeroTier if it is missing;
  - joins the router to the support ZeroTier network;
  - enables remote LuCI/SSH access through that ZeroTier network;
  - prints the router ZeroTier Node ID for authorization.

Your router password is used only for the local SSH connection from this
Windows computer to your router. The script does not save it to a file.

After installation, the support operator must authorize your router in
ZeroTier Central before they can connect.

To revoke support access later, ask the operator to remove the router from
the ZeroTier network, or disable/remove ZeroTier on the router.
