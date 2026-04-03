#!/bin/bash
# ============================================================
#   OPCUSTOM - UDP CUSTOM SERVER CONTROL
#   Uses real udp-custom binary (noobconner21/UDP-Custom-Script)
# ============================================================

UDP_DIR="/root/udp"
UDP_BIN="$UDP_DIR/udp-custom"
UDP_CFG="$UDP_DIR/config.json"
UDP_SVC="udp-custom"
UDP_PORT="20000"

# ── Start ────────────────────────────────────────────────────
start_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if [[ ! -f "$UDP_BIN" ]]; then
    echo -e "  ${R}Binary not found: $UDP_BIN${RESET}"
    echo -e "  ${Y}Run the installer again.${RESET}"
    return
  fi

  if systemctl is-active --quiet "$UDP_SVC"; then
    echo -e "  ${Y}UDP Custom already running on port $UDP_PORT.${RESET}"
    return
  fi

  systemctl start "$UDP_SVC"
  sleep 1
  if systemctl is-active --quiet "$UDP_SVC"; then
    echo -e "  ${G}✓ UDP Custom started on port $UDP_PORT${RESET}"
  else
    echo -e "  ${R}✗ Failed. Check: journalctl -u $UDP_SVC -n 20${RESET}"
  fi
}

# ── Stop ─────────────────────────────────────────────────────
stop_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  systemctl stop "$UDP_SVC" 2>/dev/null
  echo -e "  ${G}✓ UDP Custom stopped.${RESET}"
}

# ── Restart ──────────────────────────────────────────────────
restart_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  systemctl restart "$UDP_SVC"
  sleep 1
  if systemctl is-active --quiet "$UDP_SVC"; then
    echo -e "  ${G}✓ UDP Custom restarted on port $UDP_PORT${RESET}"
  else
    echo -e "  ${R}✗ Failed. Check: journalctl -u $UDP_SVC -n 20${RESET}"
  fi
}

# ── Status ───────────────────────────────────────────────────
status_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM STATUS ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if systemctl is-active --quiet "$UDP_SVC" 2>/dev/null; then
    echo -e "  Service  : ${G}RUNNING${RESET}"
  else
    echo -e "  Service  : ${R}STOPPED${RESET}"
  fi

  echo -e "  Port     : $UDP_PORT (UDP)"
  echo -e "  Binary   : $UDP_BIN"
  echo -e "  Config   : $UDP_CFG"

  local pid
  pid=$(pgrep -f "udp-custom server" | head -1)
  if [[ -n "$pid" ]]; then
    echo -e "  PID      : $pid"
    local mem
    mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
    echo -e "  Memory   : $mem"
  fi

  echo ""
  echo -e "  ${W}Config:${RESET}"
  cat "$UDP_CFG" 2>/dev/null | sed 's/^/    /' || echo "  (config not found)"

  echo ""
  echo -e "  ${W}Recent logs:${RESET}"
  journalctl -u "$UDP_SVC" -n 8 --no-pager 2>/dev/null | sed 's/^/    /' || echo "  (no logs)"
}

# ── Add user to udp-custom passwords ─────────────────────────
udpcustom_add_user() {
  local username="$1"
  local password="$2"

  # udp-custom passwords file lives in working dir
  local passfile="$UDP_DIR/passwords"
  touch "$passfile"

  # Remove existing entry for this user if any
  sed -i "/^${username}:/d" "$passfile" 2>/dev/null

  # Append new entry
  echo "${username}:${password}" >> "$passfile"

  # Reload service so it picks up new user
  systemctl reload "$UDP_SVC" 2>/dev/null || systemctl restart "$UDP_SVC" 2>/dev/null || true
}

# ── Remove user from udp-custom passwords ────────────────────
udpcustom_remove_user() {
  local username="$1"
  local passfile="$UDP_DIR/passwords"
  sed -i "/^${username}:/d" "$passfile" 2>/dev/null
  systemctl reload "$UDP_SVC" 2>/dev/null || systemctl restart "$UDP_SVC" 2>/dev/null || true
}

# ── Generate Client String ───────────────────────────────────
generate_client_string() {
  echo ""
  echo -e "  ${C}[ CLIENT CONNECTION STRING ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  local ip
  ip=$(curl -s --max-time 4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

  if [[ ! -s "$PANEL_DIR/users.db" ]]; then
    echo -e "  ${Y}No users found. Add a user first.${RESET}"
    return
  fi

  echo -e "  ${W}Select user:${RESET}"
  local i=1
  local -a users=()
  while IFS=: read -r uname pass expiry _rest; do
    echo -e "  ${Y}${i}.${RESET} $uname  (expires: $expiry)"
    users+=("$uname:$pass")
    ((i++))
  done < "$PANEL_DIR/users.db"

  echo ""
  echo -ne "  Choice: "
  read -r sel
  [[ ! "$sel" =~ ^[0-9]+$ ]] && return
  local entry="${users[$((sel-1))]}"
  [[ -z "$entry" ]] && { echo -e "  ${R}Invalid.${RESET}"; return; }

  local uname pass
  uname=$(echo "$entry" | cut -d: -f1)
  pass=$(echo "$entry" | cut -d: -f2)

  echo ""
  echo -e "  ${W}╔══════════════════════════════════════════╗${RESET}"
  echo -e "  ${W}║      HTTP CUSTOM CONNECTION INFO         ║${RESET}"
  echo -e "  ${W}╠══════════════════════════════════════════╣${RESET}"
  echo -e "  ${W}║${RESET}  Server IP  : ${G}${ip}${RESET}"
  echo -e "  ${W}║${RESET}  Port Range : ${G}1-65535${RESET}"
  echo -e "  ${W}║${RESET}  Username   : ${G}${uname}${RESET}"
  echo -e "  ${W}║${RESET}  Password   : ${G}${pass}${RESET}"
  echo -e "  ${W}║${RESET}  UDPGW      : ${G}127.0.0.1:7300${RESET}"
  echo -e "  ${W}║${RESET}  Mode       : ${G}UDP Custom${RESET}"
  echo -e "  ${W}╚══════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${C}SSH String (paste into app):${RESET}"
  echo -e "  ${G}${ip}:1-65535@${uname}:${pass}${RESET}"
}
