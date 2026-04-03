#!/bin/bash
# ============================================================
#   OPCUSTOM UDP PANEL - INSTALLER
#   github.com/OfficialOnePesewa/opcustom
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

INSTALL_DIR="/opt/opcustom"
UDP_DIR="/root/udp"
BIN_LINK="/usr/local/bin/opcustom"
REPO_RAW="https://raw.githubusercontent.com/OfficialOnePesewa/opcustom/main"
UDP_BINARY_URL="https://github.com/noobconner21/UDP-Custom-Script/raw/main/udp-custom-linux-amd64"

step() { echo -e "${YELLOW}[*]${RESET} $1"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $1"; }
warn() { echo -e "${YELLOW}[!]${RESET} $1"; }
fail() { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

[ "$EUID" -ne 0 ] && fail "Run as root."

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║       OPCUSTOM UDP PANEL INSTALLER       ║"
echo "  ║         github/OfficialOnePesewa         ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${RESET}"

# ── Step 1: Dependencies ─────────────────────────────────────
step "Installing dependencies..."
apt-get update -y -qq
apt-get install -y -qq wget curl screen cmake make gcc build-essential \
  net-tools lsof dropbear python3 unzip 2>/dev/null
ok "Dependencies ready"

# ── Step 2: Dropbear ─────────────────────────────────────────
step "Configuring Dropbear SSH..."
systemctl enable dropbear &>/dev/null
systemctl restart dropbear &>/dev/null || true
ok "Dropbear ready"

# ── Step 3: BadVPN-UDPGW ─────────────────────────────────────
if ! command -v badvpn-udpgw &>/dev/null; then
  step "Building BadVPN-UDPGW..."
  cd /tmp
  rm -rf badvpn
  wget -q https://github.com/ambrop72/badvpn/archive/refs/heads/master.tar.gz \
    -O badvpn.tar.gz || fail "Failed to download BadVPN"
  tar -xzf badvpn.tar.gz && mv badvpn-master badvpn
  cd badvpn && mkdir -p build && cd build
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 \
    -DCMAKE_INSTALL_PREFIX=/usr > /dev/null 2>&1
  make -j$(nproc) > /dev/null 2>&1
  make install > /dev/null 2>&1
  ok "BadVPN-UDPGW installed"
else
  ok "BadVPN-UDPGW already installed"
fi

# ── Step 4: UDPGW service ────────────────────────────────────
step "Setting up UDPGW service..."
cat > /etc/systemd/system/udpgw.service << 'EOF'
[Unit]
Description=BadVPN UDP Gateway
After=network.target

[Service]
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 500 --max-connections-for-client 10
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable udpgw &>/dev/null
systemctl restart udpgw
sleep 1
systemctl is-active --quiet udpgw && ok "UDPGW running on 127.0.0.1:7300" \
  || warn "UDPGW failed — check: journalctl -u udpgw -n 10"

# ── Step 5: UDP Custom binary ────────────────────────────────
step "Downloading UDP Custom server binary..."
mkdir -p "$UDP_DIR"
wget -q "$UDP_BINARY_URL" -O "$UDP_DIR/udp-custom" \
  || fail "Failed to download udp-custom binary"
chmod +x "$UDP_DIR/udp-custom"

# Write config.json
wget -q "$REPO_RAW/config.json" -O "$UDP_DIR/config.json" 2>/dev/null || \
cat > "$UDP_DIR/config.json" << 'EOF'
{
  "listen": ":20000",
  "stream_buffer": 33554432,
  "receive_buffer": 83886080,
  "auth": {
    "mode": "passwords"
  }
}
EOF
ok "UDP Custom binary ready"

# ── Step 6: UDP Custom service ───────────────────────────────
step "Creating UDP Custom service..."
cat > /etc/systemd/system/udp-custom.service << EOF
[Unit]
Description=UDP Custom Server - OPCUSTOM
After=network.target

[Service]
User=root
Type=simple
ExecStart=$UDP_DIR/udp-custom server
WorkingDirectory=$UDP_DIR/
Restart=always
RestartSec=2s

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable udp-custom &>/dev/null
systemctl restart udp-custom
sleep 2
systemctl is-active --quiet udp-custom && ok "UDP Custom running on port 20000" \
  || warn "UDP Custom failed — check: journalctl -u udp-custom -n 10"

# ── Step 7: Panel files ──────────────────────────────────────
step "Installing OPCUSTOM panel..."
mkdir -p "$INSTALL_DIR/core"

FILES=("menu.sh" "core/users.sh" "core/udpgw.sh" "core/udpcustom.sh" "core/monitor.sh")
for f in "${FILES[@]}"; do
  dest="$INSTALL_DIR/$f"
  mkdir -p "$(dirname "$dest")"
  wget -q "$REPO_RAW/$f" -O "$dest" \
    || fail "Failed to download $f — push all files to GitHub first"
  chmod +x "$dest"
done

touch "$INSTALL_DIR/users.db"
chmod 600 "$INSTALL_DIR/users.db"

ln -sf "$INSTALL_DIR/menu.sh" "$BIN_LINK"
chmod +x "$BIN_LINK"
ok "Panel installed — command: opcustom"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}  ║        INSTALLATION COMPLETE!            ║${RESET}"
echo -e "${GREEN}${BOLD}  ╚══════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}Services:${RESET}"
echo -e "  • UDPGW       →  127.0.0.1:7300"
echo -e "  • UDP Custom  →  0.0.0.0:20000"
echo -e "  • Dropbear    →  port 22"
echo ""
echo -e "  ${CYAN}HTTP Custom app:${RESET}"
echo -e "  • SSH field  →  ${BOLD}YOUR_IP:1-65535@user:pass${RESET}"
echo -e "  • Check      →  ${BOLD}UDP Custom${RESET}  +  ${BOLD}Enable DNS${RESET}"
echo -e "  • UDPGW      →  ${BOLD}127.0.0.1:7300${RESET}"
echo ""
echo -e "  ${YELLOW}Run panel:${RESET} ${BOLD}opcustom${RESET}"
echo ""
