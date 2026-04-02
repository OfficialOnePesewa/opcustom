#!/bin/bash
# ============================================================
#   OPCUSTOM UDP PANEL - MAIN MENU
#   github.com/OfficialOnePesewa/opcustom
# ============================================================

# Resolve real path (symlink-safe)
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
PANEL_DIR="$(dirname "$SELF")"

[ "$EUID" -ne 0 ] && { echo "Run as root."; exit 1; }

# Source core modules
_src() {
  local f="$PANEL_DIR/$1"
  if [[ ! -f "$f" ]]; then
    echo -e "\033[0;31m[✗] Missing: $f"
    echo "    Reinstall: bash <(curl -s https://raw.githubusercontent.com/OfficialOnePesewa/opcustom/main/install.sh)\033[0m"
    exit 1
  fi
  source "$f"
}

_src "core/users.sh"
_src "core/udpgw.sh"
_src "core/monitor.sh"

# ── Colors & styles ──────────────────────────────────────────
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; B='\033[1m'; W='\033[1;37m'; RESET='\033[0m'

# ── Helper: pause ────────────────────────────────────────────
pause() { echo ""; read -rp "  Press Enter to continue..." _; }

# ── Header ───────────────────────────────────────────────────
show_header() {
  clear
  local udp_status
  if systemctl is-active --quiet udpgw 2>/dev/null; then
    udp_status="${G}RUNNING${RESET}"
  else
    udp_status="${R}STOPPED${RESET}"
  fi

  local user_count
  user_count=$(wc -l < "$PANEL_DIR/users.db" 2>/dev/null || echo 0)

  local ip
  ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

  echo -e "${C}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║         OPCUSTOM UDP PANEL  v2.0             ║"
  echo "  ║      github/OfficialOnePesewa                ║"
  echo "  ╠══════════════════════════════════════════════╣"
  printf "  ║  %-12s %-32s ║\n" "IP:" "$ip"
  printf "  ║  %-12s " "UDPGW:"
  echo -e "%-32b ║" "$udp_status"
  printf "  ║  %-12s %-32s ║\n" "Users:" "$user_count"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

# ── Main menu ────────────────────────────────────────────────
show_menu() {
  echo -e "${W}  ┌─────────────────────────────────────┐${RESET}"
  echo -e "${W}  │           USER MANAGEMENT           │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "  │  ${Y}1.${RESET} Add User                         │"
  echo -e "  │  ${Y}2.${RESET} List Users                       │"
  echo -e "  │  ${Y}3.${RESET} Delete User                      │"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "${W}  │           UDPGW CONTROL             │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "  │  ${C}4.${RESET} Start UDPGW                      │"
  echo -e "  │  ${C}5.${RESET} Stop UDPGW                       │"
  echo -e "  │  ${C}6.${RESET} Restart UDPGW                    │"
  echo -e "  │  ${C}7.${RESET} UDPGW Status                     │"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "${W}  │              TOOLS                  │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "  │  ${G}8.${RESET} Monitor Connections              │"
  echo -e "  │  ${G}9.${RESET} View System Info                 │"
  echo -e "${W}  ├─────────────────────────────────────┤${RESET}"
  echo -e "  │  ${R}0.${RESET} Exit                             │"
  echo -e "${W}  └─────────────────────────────────────┘${RESET}"
  echo ""
  echo -ne "  ${B}Select option:${RESET} "
}

# ── Main loop ────────────────────────────────────────────────
while true; do
  show_header
  show_menu
  read -r choice

  case "$choice" in
    1) add_user;    pause ;;
    2) list_users;  pause ;;
    3) delete_user; pause ;;
    4) start_udpgw;   pause ;;
    5) stop_udpgw;    pause ;;
    6) restart_udpgw; pause ;;
    7) status_udpgw;  pause ;;
    8) monitor_connections ;;
    9) system_info; pause ;;
    0) echo -e "\n  ${C}Goodbye!${RESET}\n"; exit 0 ;;
    "") continue ;;
    *) echo -e "\n  ${R}Invalid option. Try again.${RESET}"; sleep 1 ;;
  esac
done
