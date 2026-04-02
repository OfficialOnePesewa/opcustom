OPCUSTOM UDP Panel
A clean Bash TUI for managing BadVPN-UDPGW and SSH/Dropbear users on Ubuntu/Debian VPS.
Install
bash <(curl -s https://raw.githubusercontent.com/OfficialOnePesewa/opcustom/main/install.sh)
Then run:
opcustom
Features
Add / List / Delete users (with system auth via Dropbear)
Start / Stop / Restart / Status UDPGW service
Live connection monitor
System info dashboard
Symlink-safe (works via /usr/local/bin/opcustom)
File Structure
opcustom/
├── install.sh        # Installer
├── menu.sh           # Main TUI menu
├── users.db          # User database (auto-created)
└── core/
    ├── users.sh      # User management
    ├── udpgw.sh      # UDPGW service control
    └── monitor.sh    # Connection monitor & system info
Requirements
Debian 9–12 / Ubuntu 16–24
Root access
Port 7300 open for UDPGW
OP Data Solutions · @OfficialOnePesewa
