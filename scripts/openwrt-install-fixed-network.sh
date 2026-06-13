#!/bin/sh
set -eu

NETWORK_ID="${ZRS_NETWORK_ID:-}"
BASE_URL="${ZRS_BASE_URL:-https://raw.githubusercontent.com/moz9/zerotier-router-support/main}"
BACKUP_ROOT="${ZRS_BACKUP_ROOT:-/root/zt-router-support-backups}"
TMP_DIR="$(mktemp -d /tmp/zrs-oneclick.XXXXXX)"

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

die() {
  echo "ERROR: $*" >&2
  exit 1
}

step() {
  echo
  echo "== $* =="
}

download() {
  url="$1"
  dest="$2"
  mkdir -p "$(dirname "$dest")"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  elif command -v uclient-fetch >/dev/null 2>&1; then
    uclient-fetch -q -O "$dest" "$url"
  else
    die "no downloader found: install wget, curl, or uclient-fetch"
  fi
}

need_openwrt_root() {
  [ "$(id -u)" = 0 ] || die "run this script as root"
  [ -f /etc/openwrt_release ] || die "this does not look like OpenWrt: /etc/openwrt_release is missing"
}

validate_network_id() {
  [ -n "$NETWORK_ID" ] || die "missing ZeroTier Network ID: set ZRS_NETWORK_ID"
  printf '%s' "$NETWORK_ID" | grep -Eq '^[0-9a-fA-F]{16}$' || die "bad ZeroTier Network ID: $NETWORK_ID"
}

make_backup() {
  ts="$(date +%Y%m%d-%H%M%S)"
  dir="${BACKUP_ROOT}/${ts}"
  archive="${BACKUP_ROOT}/config-before-zerotier-${ts}.tar.gz"

  mkdir -p "${dir}/etc-config"
  cp -pR /etc/config/. "${dir}/etc-config/"
  cp /etc/openwrt_release "${dir}/openwrt_release" 2>/dev/null || true
  ubus call system board > "${dir}/system-board.json" 2>/dev/null || true
  uci export > "${dir}/uci.export" 2>/dev/null || true

  tar -czf "$archive" -C "$dir" .
  printf '%s\n' "$archive" > "${BACKUP_ROOT}/last-backup-path"
  sync

  echo "BACKUP_FILE=$archive"
}

install_support_panel() {
  installer="${TMP_DIR}/router-direct-install.sh"
  download "${BASE_URL}/router-direct-install.sh" "$installer"
  chmod 0755 "$installer"
  sh "$installer"
}

dropbear_ports() {
  uci -q show dropbear 2>/dev/null |
    sed -n "s/^dropbear\\..*\\.Port='\\{0,1\\}\\([^']*\\)'\\{0,1\\}$/\\1/p" |
    tr '\n' ' '
}

ensure_zt_access_ports() {
  if ! uci -q get firewall.allow_zt_support_router >/dev/null 2>&1; then
    echo "ZeroTier firewall rule was not found; skipping port normalization."
    return 0
  fi

  uci -q delete firewall.allow_zt_support_router.dest_port || true

  seen=""
  for port in 22 80 443 $(dropbear_ports); do
    case "$port" in
      ''|*[!0-9]*) continue ;;
    esac

    case " $seen " in
      *" $port "*) ;;
      *)
        uci add_list "firewall.allow_zt_support_router.dest_port=$port"
        seen="$seen $port"
      ;;
    esac
  done

  uci commit firewall
  /etc/init.d/firewall reload >/dev/null 2>&1 || /etc/init.d/firewall restart >/dev/null 2>&1 || true
  echo "ZT_ALLOWED_PORTS=${seen# }"
}

configure_network() {
  helper="/usr/libexec/zerotier-support/helper"
  [ -x "$helper" ] || die "support helper was not installed: $helper"

  "$helper" configure "$NETWORK_ID"
  ensure_zt_access_ports
}

print_final_status() {
  echo
  echo "== Final status =="
  zerotier-cli info 2>&1 || true
  zerotier-cli listnetworks 2>&1 || true

  node_id="$(zerotier-cli info 2>/dev/null | awk '/^200 info / {print $3; exit}' || true)"
  zt_ip="$(zerotier-cli listnetworks 2>/dev/null | awk -v id="$NETWORK_ID" '$3 == id {for (i=9; i<=NF; i++) print $i}' | head -n 1 || true)"
  zt_ip_plain="$(printf '%s' "$zt_ip" | cut -d/ -f1)"

  echo
  echo "ZERO_TIER_NETWORK_ID=$NETWORK_ID"
  [ -n "$node_id" ] && echo "ZERO_TIER_NODE_ID=$node_id"
  [ -n "$zt_ip" ] && echo "ZERO_TIER_IP=$zt_ip"
  [ -n "$zt_ip_plain" ] && echo "LUCI_URL=http://${zt_ip_plain}/cgi-bin/luci/"
  [ -n "$zt_ip_plain" ] && echo "SSH_EXAMPLE=ssh root@${zt_ip_plain}"
  echo
  echo "If status is ACCESS_DENIED or REQUESTING_CONFIGURATION, authorize this router in ZeroTier Central."
}

need_openwrt_root
validate_network_id

step "OpenWrt system"
cat /etc/openwrt_release 2>/dev/null || true
ubus call system board 2>/dev/null || true

step "Backup current router config"
make_backup

step "Install ZeroTier support panel"
install_support_panel

step "Join fixed ZeroTier network"
configure_network

print_final_status
