#!/bin/bash
# ============================================================
#   OPCUSTOM - MONITOR & SYSTEM INFO
# ============================================================

monitor_connections() {
  echo ""; echo -e "  ${C}[ LIVE CONNECTION MONITOR ]${RESET}"
  echo -e "  ${Y}Press Ctrl+C to exit${RESET}"; sleep 1
  while true; do
    clear
    echo -e "${C}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║        OPCUSTOM - LIVE CONNECTIONS           ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo -e "  ${W}Time: ${RESET}$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo -e "  ${W}[ Active SSH Sessions ]${RESET}"
    echo -e "  ${W}────────────────────────────────────────────${RESET}"
    local s; s=$(who 2>/dev/null)
    [[ -z "$s" ]] && echo -e "  ${Y}None.${RESET}" || \
      { printf "  ${W}%-16s %-16s %-16s${RESET}\n" "User" "IP" "Time"; echo "$s" | \
        awk '{printf "  %-16s %-16s %s\n", $1, $5, $3" "$4}'; }
    echo ""
    echo -e "  ${W}[ UDP Custom Port 20000 ]${RESET}"
    echo -e "  ${W}────────────────────────────────────────────${RESET}"
    echo -e "  Connections: ${G}$(ss -unp 2>/dev/null | grep ":20000" | wc -l)${RESET}"
    echo -e "  UDPGW      : ${G}$(ss -tnp 2>/dev/null | grep ":7300" | wc -l) conn${RESET}"
    echo ""
    echo -e "  ${Y}Refreshing in 5s... Ctrl+C to stop${RESET}"
    sleep 5
  done
}

system_info() {
  echo ""; echo -e "  ${C}[ SYSTEM INFO ]${RESET}"
  echo -e "  ${W}────────────────────────────────────────────${RESET}"
  local os; os=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  echo -e "  OS       : ${os:-Unknown}"
  echo -e "  Uptime   : $(uptime -p 2>/dev/null | sed 's/up //' || echo N/A)"
  local cores load; cores=$(nproc); load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
  echo -e "  CPU      : $cores core(s)  |  Load: $load"
  free -m 2>/dev/null | awk '/Mem:/{printf "  RAM      : %sMB used / %sMB total\n", $3, $2}'
  df -h / 2>/dev/null | awk 'NR==2{printf "  Disk     : %s used / %s total (%s)\n", $3, $2, $5}'
  local pub; pub=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo N/A)
  echo -e "  Public IP: $pub"
  echo -e "  Local IP : $(hostname -I | awk '{print $1}')"
  echo ""
  echo -e "  ${W}[ Service Status ]${RESET}"
  for svc in udpgw udp-custom dropbear; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
      echo -e "  ${G}●${RESET} $svc  ${G}running${RESET}"
    else
      echo -e "  ${R}●${RESET} $svc  ${R}stopped${RESET}"
    fi
  done
  echo -e "  ${W}────────────────────────────────────────────${RESET}"
}
