#!/bin/bash
# ============================================================
#   OPCUSTOM - UDPGW SERVICE CONTROL
# ============================================================

SERVICE="udpgw"

_udpgw_is_active() {
  systemctl is-active --quiet "$SERVICE" 2>/dev/null
}

# ── Start ────────────────────────────────────────────────────
start_udpgw() {
  echo ""
  echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if _udpgw_is_active; then
    echo -e "  ${Y}UDPGW is already running.${RESET}"
    return
  fi

  echo -ne "  Starting UDPGW..."
  systemctl start "$SERVICE" 2>/dev/null
  sleep 1
  if _udpgw_is_active; then
    echo -e " ${G}OK${RESET}"
    echo -e "  ${G}✓ UDPGW started on 127.0.0.1:7300${RESET}"
  else
    echo -e " ${R}FAILED${RESET}"
    echo -e "  ${R}Check: journalctl -u $SERVICE -n 20${RESET}"
  fi
}

# ── Stop ─────────────────────────────────────────────────────
stop_udpgw() {
  echo ""
  echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if ! _udpgw_is_active; then
    echo -e "  ${Y}UDPGW is not running.${RESET}"
    return
  fi

  echo -ne "  Stopping UDPGW..."
  systemctl stop "$SERVICE" 2>/dev/null
  sleep 1
  if ! _udpgw_is_active; then
    echo -e " ${G}OK${RESET}"
    echo -e "  ${G}✓ UDPGW stopped.${RESET}"
  else
    echo -e " ${R}FAILED${RESET}"
  fi
}

# ── Restart ──────────────────────────────────────────────────
restart_udpgw() {
  echo ""
  echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  echo -ne "  Restarting UDPGW..."
  systemctl restart "$SERVICE" 2>/dev/null
  sleep 1
  if _udpgw_is_active; then
    echo -e " ${G}OK${RESET}"
    echo -e "  ${G}✓ UDPGW restarted on 127.0.0.1:7300${RESET}"
  else
    echo -e " ${R}FAILED${RESET}"
    echo -e "  ${R}Check: journalctl -u $SERVICE -n 20${RESET}"
  fi
}

# ── Status ───────────────────────────────────────────────────
status_udpgw() {
  echo ""
  echo -e "  ${C}[ UDPGW STATUS ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if _udpgw_is_active; then
    echo -e "  Service  : ${G}RUNNING${RESET}"
  else
    echo -e "  Service  : ${R}STOPPED${RESET}"
  fi

  local pid
  pid=$(pgrep -f "badvpn-udpgw" | head -1)
  if [[ -n "$pid" ]]; then
    echo -e "  PID      : $pid"
    local mem
    mem=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "%.1f MB", $1/1024}')
    echo -e "  Memory   : $mem"
    local uptime_sec
    uptime_sec=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    if [[ -n "$uptime_sec" ]]; then
      printf "  Uptime   : %dh %dm %ds\n" $((uptime_sec/3600)) $((uptime_sec%3600/60)) $((uptime_sec%60))
    fi
  fi

  echo -e "  Listen   : 127.0.0.1:7300"
  echo ""
  echo -e "  ${W}Recent logs:${RESET}"
  journalctl -u "$SERVICE" -n 8 --no-pager 2>/dev/null | \
    sed 's/^/    /' || echo "  (no logs)"
}
