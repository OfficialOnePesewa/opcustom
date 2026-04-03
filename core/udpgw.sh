#!/bin/bash
# ============================================================
#   OPCUSTOM - UDPGW SERVICE CONTROL
# ============================================================

SERVICE="udpgw"

_udpgw_is_active() { systemctl is-active --quiet "$SERVICE" 2>/dev/null; }

start_udpgw() {
  echo ""; echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  _udpgw_is_active && { echo -e "  ${Y}UDPGW already running.${RESET}"; return; }
  echo -ne "  Starting UDPGW..."
  systemctl start "$SERVICE" 2>/dev/null; sleep 1
  _udpgw_is_active && echo -e " ${G}OK${RESET}" || echo -e " ${R}FAILED${RESET}"
}

stop_udpgw() {
  echo ""; echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  ! _udpgw_is_active && { echo -e "  ${Y}UDPGW not running.${RESET}"; return; }
  systemctl stop "$SERVICE" 2>/dev/null
  echo -e "  ${G}✓ UDPGW stopped.${RESET}"
}

restart_udpgw() {
  echo ""; echo -e "  ${C}[ UDPGW CONTROL ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  systemctl restart "$SERVICE" 2>/dev/null; sleep 1
  _udpgw_is_active && echo -e "  ${G}✓ UDPGW restarted on 127.0.0.1:7300${RESET}" \
    || echo -e "  ${R}✗ Failed. Check: journalctl -u $SERVICE -n 20${RESET}"
}

status_udpgw() {
  echo ""; echo -e "  ${C}[ UDPGW STATUS ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  _udpgw_is_active && echo -e "  Service  : ${G}RUNNING${RESET}" \
    || echo -e "  Service  : ${R}STOPPED${RESET}"
  echo -e "  Listen   : 127.0.0.1:7300"
  local pid; pid=$(pgrep -f "badvpn-udpgw" | head -1)
  if [[ -n "$pid" ]]; then
    echo -e "  PID      : $pid"
    ps -o rss= -p "$pid" 2>/dev/null | awk '{printf "  Memory   : %.1f MB\n", $1/1024}'
    local up; up=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ -n "$up" ]] && printf "  Uptime   : %dh %dm %ds\n" $((up/3600)) $((up%3600/60)) $((up%60))
  fi
  echo ""; echo -e "  ${W}Recent logs:${RESET}"
  journalctl -u "$SERVICE" -n 6 --no-pager 2>/dev/null | sed 's/^/    /' || echo "  (no logs)"
}
