# Security Policy

This repository contains installer files for configuring ZeroTier access on OpenWrt routers. The repository is public even though its historical name contains `private`.

## Supported use

The default branch contains the current supported installer. When sharing install commands with other people, prefer a tagged release or a pinned commit URL instead of a moving `main` URL.

## Secrets and private data

Do not commit router passwords, SSH private keys, ZeroTier tokens, API tokens, `.env` files, router backups, customer-specific settings, fixed private Network IDs, or operator-only notes.

A ZeroTier Network ID is not a password, but it can reveal or target a private support network. Treat customer-specific Network IDs as operationally sensitive and pass them at setup time instead of hard-coding them here.

## Reporting a security issue

Do not disclose exploitable issues publicly before they are fixed. Report them through the existing private support channel for this project or contact the repository owner directly.

Useful report details:

- affected script;
- Windows PowerShell version or OpenWrt version;
- exact command used, with secrets removed;
- expected behavior and actual behavior.
