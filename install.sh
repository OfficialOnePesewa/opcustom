#!/bin/bash
# ============================================================
#   OPCUSTOM UDP PANEL - INSTALLER
#   github.com/OfficialOnePesewa/opcustom
# ============================================================

set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

INSTALL_DIR="/opt/opcustom"
BIN_LINK="/usr/local/bin/opcustom"
REPO_RAW="https://raw.githubusercontent.com/OfficialOnePesewa/opcustom/main"

print_banner() {
  clear
  echo -e "${CYAN}"
  echo "  ╔══════════════════════════════════════════╗"
  echo "  ║       OPCUSTOM UDP PANEL INSTALLER       ║"
  echo "  ║         github/OfficialOnePesewa         ║"
  echo "  ╚══════════════════════════════════════════╝"
  echo -e "${RESET}"
}

step() { echo -e "${YELLOW}[*]${RESET} $1"; }
ok()   { echo -e "${GREEN}[✓]${RESET} $1"; }
fail() { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

[ "$EUID" -ne 0 ] && fail "Run as root."

print_banner

# ── Step 1: Update & deps ────────────────────────────────────
step "Installing dependencies..."
apt-get update -y -qq
apt-get install -y -qq curl wget screen cmake make gcc build-essential \
  net-tools lsof dropbear 2>/dev/null
ok "Dependencies installed"

# ── Step 2: Enable Dropbear ──────────────────────────────────
step "Enabling Dropbear SSH..."
systemctl enable dropbear &>/dev/null
systemctl restart dropbear &>/dev/null || true
ok "Dropbear ready"

# ── Step 3: Install BadVPN-UDPGW ────────────────────────────
if ! command -v badvpn-udpgw &>/dev/null; then
  step "Building BadVPN-UDPGW from source..."
  cd /tmp
  rm -rf badvpn
  wget -q https://github.com/ambrop72/badvpn/archive/refs/heads/master.tar.gz \
    -O badvpn.tar.gz || fail "Failed to download BadVPN"
  tar -xzf badvpn.tar.gz
  mv badvpn-master badvpn
  cd badvpn
  mkdir -p build && cd build
  cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1 -DCMAKE_INSTALL_PREFIX=/usr \
    > /dev/null 2>&1
  make -j$(nproc) > /dev/null 2>&1
  make install > /dev/null 2>&1
  ok "BadVPN-UDPGW installed → $(which badvpn-udpgw)"
else
  ok "BadVPN-UDPGW already installed"
fi

# ── Step 4: Install panel files ──────────────────────────────
step "Installing OPCUSTOM panel..."
mkdir -p "$INSTALL_DIR/core"

FILES=("menu.sh" "core/users.sh" "core/udpgw.sh" "core/monitor.sh")
for f in "${FILES[@]}"; do
  dest="$INSTALL_DIR/$f"
  mkdir -p "$(dirname "$dest")"
  if wget -q "$REPO_RAW/$f" -O "$dest"; then
    chmod +x "$dest"
  else
    fail "Failed to download $f — check your repo has all files pushed"
  fi
done

# users.db
touch "$INSTALL_DIR/users.db"
chmod 600 "$INSTALL_DIR/users.db"
ok "Panel files installed to $INSTALL_DIR"

# ── Step 5: Create symlink ───────────────────────────────────
step "Creating opcustom command..."
ln -sf "$INSTALL_DIR/menu.sh" "$BIN_LINK"
chmod +x "$BIN_LINK"
ok "Run with: opcustom"

# ── Step 6: Create UDPGW systemd service ────────────────────
step "Creating UDPGW systemd service..."
cat > /etc/systemd/system/udpgw.service <<'EOF'
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
ok "UDPGW service created (use panel to start)"

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ✅ INSTALLATION COMPLETE!${RESET}"
echo -e "${CYAN}  ➤  Type: ${BOLD}opcustom${RESET}${CYAN} to launch the panel${RESET}"
echo ""
