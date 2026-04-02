#!/bin/bash
# ============================================================
#   OPCUSTOM - MONITOR & SYSTEM INFO
# ============================================================

# ── Monitor Connections ──────────────────────────────────────
monitor_connections() {
  echo ""
  echo -e "  ${C}[ LIVE CONNECTION MONITOR ]${RESET}"
  echo -e "  ${Y}Press Ctrl+C to exit${RESET}"
  echo ""
  sleep 1

  while true; do
    clear
    echo -e "${C}"
    echo "  ╔══════════════════════════════════════════════╗"
    echo "  ║        OPCUSTOM - LIVE CONNECTIONS           ║"
    echo "  ╚══════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "  ${W}Time: ${RESET}$(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Active SSH/Dropbear sessions
    echo -e "  ${W}[ SSH / Dropbear Sessions ]${RESET}"
    echo -e "  ${W}────────────────────────────────────────────${RESET}"
    local sessions
    sessions=$(who 2>/dev/null | awk '{printf "  %-16s %-16s %s\n", $1, $5, $3" "$4}')
    if [[ -z "$sessions" ]]; then
      echo -e "  ${Y}No active sessions.${RESET}"
    else
      printf "  ${W}%-16s %-16s %-16s${RESET}\n" "User" "IP" "Login Time"
      echo "$sessions"
    fi

    echo ""
    # UDPGW connections
    echo -e "  ${W}[ UDPGW Port 7300 ]${RESET}"
    echo -e "  ${W}────────────────────────────────────────────${RESET}"
    local udp_conns
    udp_conns=$(ss -tnp 2>/dev/null | grep ":7300" | wc -l)
    echo -e "  Active connections: ${G}${udp_conns}${RESET}"

    echo ""
    # Network traffic
    echo -e "  ${W}[ Network Traffic ]${RESET}"
    echo -e "  ${W}────────────────────────────────────────────${RESET}"
    local iface
    iface=$(ip route | awk '/default/{print $5; exit}')
    if [[ -n "$iface" ]]; then
      local rx tx
      rx=$(cat /sys/class/net/"$iface"/statistics/rx_bytes 2>/dev/null || echo 0)
      tx=$(cat /sys/class/net/"$iface"/statistics/tx_bytes 2>/dev/null || echo 0)
      printf "  RX: %s MB   TX: %s MB\n" \
        "$(echo "$rx" | awk '{printf "%.1f", $1/1024/1024}')" \
        "$(echo "$tx" | awk '{printf "%.1f", $1/1024/1024}')"
    fi

    echo ""
    echo -e "  ${Y}Refreshing in 5s... (Ctrl+C to stop)${RESET}"
    sleep 5
  done
}

# ── System Info ──────────────────────────────────────────────
system_info() {
  echo ""
  echo -e "  ${C}[ SYSTEM INFO ]${RESET}"
  echo -e "  ${W}────────────────────────────────────────────${RESET}"

  # OS
  local os
  os=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')
  echo -e "  OS       : ${os:-Unknown}"

  # Uptime
  local uptime_str
  uptime_str=$(uptime -p 2>/dev/null | sed 's/up //')
  echo -e "  Uptime   : ${uptime_str:-N/A}"

  # CPU
  local cpu_model cpu_cores cpu_load
  cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs)
  cpu_cores=$(nproc 2>/dev/null || echo "?")
  cpu_load=$(cut -d' ' -f1 /proc/loadavg 2>/dev/null)
  echo -e "  CPU      : ${cpu_model:-Unknown} (${cpu_cores} core(s))"
  echo -e "  Load     : $cpu_load"

  # RAM
  local total used
  total=$(free -m 2>/dev/null | awk '/Mem:/{print $2}')
  used=$(free -m 2>/dev/null | awk '/Mem:/{print $3}')
  echo -e "  RAM      : ${used}MB used / ${total}MB total"

  # Disk
  local disk
  disk=$(df -h / 2>/dev/null | awk 'NR==2{printf "%s used / %s total (%s)", $3, $2, $5}')
  echo -e "  Disk     : $disk"

  # IP
  local pub_ip priv_ip
  pub_ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || echo "N/A")
  priv_ip=$(hostname -I | awk '{print $1}')
  echo -e "  Public IP: $pub_ip"
  echo -e "  Local IP : $priv_ip"

  # Ports
  echo ""
  echo -e "  ${W}[ Listening Ports ]${RESET}"
  ss -tlnp 2>/dev/null | awk 'NR>1{print $4}' | \
    grep -oP ':\K\d+' | sort -nu | \
    awk '{printf "  %s", $0; if(NR%8==0) printf "\n"}' && echo ""

  echo -e "  ${W}────────────────────────────────────────────${RESET}"
}
