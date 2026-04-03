#!/bin/bash
# ============================================================
#   OPCUSTOM UDP PANEL - MAIN MENU
#   github.com/OfficialOnePesewa/opcustom
# ============================================================

SELF="$(readlink -f "${BASH_SOURCE[0]}")"
PANEL_DIR="$(dirname "$SELF")"

[ "$EUID" -ne 0 ] && { echo "Run as root."; exit 1; }

_src() {
  local f="$PANEL_DIR/$1"
  if [[ ! -f "$f" ]]; then
    echo -e "\033[0;31m[✗] Missing: $f"
    echo "    Reinstall: bash <(wget -qO- https://raw.githubusercontent.com/OfficialOnePesewa/opcustom/main/install.sh)\033[0m"
    exit 1
  fi
  source "$f"
}

_src "core/udpcustom.sh"   # load first — users.sh calls udpcustom_add_user
_src "core/users.sh"
_src "core/udpgw.sh"
_src "core/monitor.sh"

R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'
C='\033[0;36m'; W='\033[1;37m'; RESET='\033[0m'

pause() { echo ""; read -rp "  Press Enter to continue..." _; }

show_header() {
  clear
  local udpgw_st udpcustom_st user_count ip

  systemctl is-active --quiet udpgw 2>/dev/null \
    && udpgw_st="${G}RUNNING${RESET}" || udpgw_st="${R}STOPPED${RESET}"

  systemctl is-active --quiet udp-custom 2>/dev/null \
    && udpcustom_st="${G}RUNNING${RESET}" || udpcustom_st="${R}STOPPED${RESET}"

  user_count=$(wc -l < "$PANEL_DIR/users.db" 2>/dev/null || echo 0)
  ip=$(curl -s --max-time 3 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

  echo -e "${C}"
  echo "  ╔══════════════════════════════════════════════╗"
  echo "  ║         OPCUSTOM UDP PANEL  v2.1             ║"
  echo "  ║       github/OfficialOnePesewa               ║"
  echo "  ╠══════════════════════════════════════════════╣"
  printf "  ║  %-14s %-30s ║\n" "Server IP:" "$ip"
  printf "  ║  %-14s " "UDPGW :7300:"
  echo -e "%-30b ║" "$udpgw_st"
  printf "  ║  %-14s " "UDP Custom:"
  echo -e "%-30b ║" "$udpcustom_st"
  printf "  ║  %-14s %-30s ║\n" "Users:" "$user_count"
  echo "  ╚══════════════════════════════════════════════╝"
  echo -e "${RESET}"
}

show_menu() {
  echo -e "${W}  ┌─────────────────────────────────────────┐${RESET}"
  echo -e "${W}  │           USER MANAGEMENT               │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "  │  ${Y}1.${RESET}  Add User                           │"
  echo -e "  │  ${Y}2.${RESET}  List Users                         │"
  echo -e "  │  ${Y}3.${RESET}  Delete User                        │"
  echo -e "  │  ${Y}4.${RESET}  Client Connection String           │"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "${W}  │           UDPGW CONTROL                 │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "  │  ${C}5.${RESET}  Start UDPGW                        │"
  echo -e "  │  ${C}6.${RESET}  Stop UDPGW                         │"
  echo -e "  │  ${C}7.${RESET}  Restart UDPGW                      │"
  echo -e "  │  ${C}8.${RESET}  UDPGW Status                       │"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "${W}  │         UDP CUSTOM SERVER               │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "  │  ${G}9.${RESET}  Start UDP Custom                   │"
  echo -e "  │  ${G}10.${RESET} Stop UDP Custom                    │"
  echo -e "  │  ${G}11.${RESET} Restart UDP Custom                 │"
  echo -e "  │  ${G}12.${RESET} UDP Custom Status                  │"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "${W}  │              TOOLS                      │${RESET}"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "  │  ${Y}13.${RESET} Monitor Connections                │"
  echo -e "  │  ${Y}14.${RESET} System Info                        │"
  echo -e "${W}  ├─────────────────────────────────────────┤${RESET}"
  echo -e "  │  ${R}0.${RESET}  Exit                               │"
  echo -e "${W}  └─────────────────────────────────────────┘${RESET}"
  echo ""
  echo -ne "  Select: "
}

while true; do
  show_header
  show_menu
  read -r choice

  case "$choice" in
    1)  add_user;               pause ;;
    2)  list_users;             pause ;;
    3)  delete_user;            pause ;;
    4)  generate_client_string; pause ;;
    5)  start_udpgw;            pause ;;
    6)  stop_udpgw;             pause ;;
    7)  restart_udpgw;          pause ;;
    8)  status_udpgw;           pause ;;
    9)  start_udpcustom;        pause ;;
    10) stop_udpcustom;         pause ;;
    11) restart_udpcustom;      pause ;;
    12) status_udpcustom;       pause ;;
    13) monitor_connections ;;
    14) system_info;            pause ;;
    0)  echo -e "\n  ${C}Goodbye!${RESET}\n"; exit 0 ;;
    "") continue ;;
    *)  echo -e "\n  ${R}Invalid option.${RESET}"; sleep 1 ;;
  esac
done
