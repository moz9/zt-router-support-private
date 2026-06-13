#!/bin/sh
set -eu

NETWORK_ID="${1:-${ZRS_NETWORK_ID:-}}"

if [ -z "$NETWORK_ID" ]; then
  echo "Usage: ZRS_NETWORK_ID='<network-id>' sh $0" >&2
  echo "   or: sh $0 '<network-id>'" >&2
  exit 1
fi

if command -v zerotier-cli >/dev/null 2>&1; then
  zerotier-cli leave "$NETWORK_ID" >/dev/null 2>&1 || true
fi

if [ -x /usr/libexec/zerotier-support/helper ]; then
  /usr/libexec/zerotier-support/helper leave "$NETWORK_ID" >/dev/null 2>&1 || true
  /usr/libexec/zerotier-support/helper disable >/dev/null 2>&1 || true
fi

uci -q delete firewall.zt_support || true
uci -q delete firewall.allow_zt_support_router || true
uci commit firewall || true
/etc/init.d/firewall reload >/dev/null 2>&1 || /etc/init.d/firewall restart >/dev/null 2>&1 || true

echo "ZeroTier support network disabled for $NETWORK_ID."
echo "Also remove or deauthorize this member in ZeroTier Central."
