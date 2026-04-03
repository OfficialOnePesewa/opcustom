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
  net-tools lsof dropbear python3 2>/dev/null
ok "Dependencies installed"

# ── Step 2: Enable Dropbear ──────────────────────────────────
step "Configuring Dropbear SSH..."
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
step "Installing OPCUSTOM panel files..."
mkdir -p "$INSTALL_DIR/core"

FILES=("menu.sh" "core/users.sh" "core/udpgw.sh" "core/udpcustom.sh" "core/monitor.sh")
for f in "${FILES[@]}"; do
  dest="$INSTALL_DIR/$f"
  mkdir -p "$(dirname "$dest")"
  if wget -q "$REPO_RAW/$f" -O "$dest"; then
    chmod +x "$dest"
  else
    fail "Failed to download $f — make sure all files are pushed to the repo"
  fi
done

touch "$INSTALL_DIR/users.db"
chmod 600 "$INSTALL_DIR/users.db"
ok "Panel files installed to $INSTALL_DIR"

# ── Step 5: Symlink ──────────────────────────────────────────
step "Creating opcustom command..."
ln -sf "$INSTALL_DIR/menu.sh" "$BIN_LINK"
chmod +x "$BIN_LINK"
ok "Command ready: opcustom"

# ── Step 6: UDPGW systemd service ───────────────────────────
step "Creating UDPGW service..."
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
systemctl start udpgw
sleep 1
if systemctl is-active --quiet udpgw; then
  ok "UDPGW running on 127.0.0.1:7300"
else
  echo -e "${RED}[!]${RESET} UDPGW failed — check: journalctl -u udpgw -n 20"
fi

# ── Step 7: UDP Custom server ────────────────────────────────
step "Installing UDP Custom server..."

UDPCUSTOM_SCRIPT="/usr/local/bin/udpcustom-server"

cat > "$UDPCUSTOM_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
"""
UDP Custom Server for HTTP Custom VPN app
Accepts UDP on port 20000, tunnels through BadVPN UDPGW :7300
"""
import socket, threading, struct, sys, os, signal, time

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(os.environ.get("UDPCUSTOM_PORT", 20000))
UDPGW_HOST  = "127.0.0.1"
UDPGW_PORT  = int(os.environ.get("UDPGW_PORT", 7300))
BUFFER_SIZE = 65535
TIMEOUT     = 120

print(f"[UDP Custom] Listening on {LISTEN_HOST}:{LISTEN_PORT}")
print(f"[UDP Custom] Forwarding to UDPGW {UDPGW_HOST}:{UDPGW_PORT}")

clients = {}
lock    = threading.Lock()

def relay_back(gw, addr, srv):
    try:
        while True:
            resp = gw.recv(BUFFER_SIZE)
            if not resp: break
            payload = resp[2:] if len(resp) > 2 else resp
            srv.sendto(payload, addr)
    except: pass
    finally:
        with lock:
            if addr in clients:
                try: clients[addr]["sock"].close()
                except: pass
                del clients[addr]

def handle(data, addr, srv):
    with lock:
        if addr not in clients:
            try:
                s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                s.settimeout(TIMEOUT)
                s.connect((UDPGW_HOST, UDPGW_PORT))
                clients[addr] = {"sock": s, "last": time.time()}
                threading.Thread(target=relay_back, args=(s, addr, srv), daemon=True).start()
            except Exception as e:
                print(f"[UDP Custom] GW error: {e}"); return
        else:
            clients[addr]["last"] = time.time()
        gw = clients.get(addr, {}).get("sock")
    if gw:
        try: gw.sendall(struct.pack(">H", len(data)) + data)
        except:
            with lock:
                if addr in clients:
                    try: clients[addr]["sock"].close()
                    except: pass
                    del clients[addr]

def cleanup():
    while True:
        time.sleep(30)
        now = time.time()
        with lock:
            stale = [k for k,v in clients.items() if now - v["last"] > TIMEOUT]
            for k in stale:
                try: clients[k]["sock"].close()
                except: pass
                del clients[k]

signal.signal(signal.SIGTERM, lambda s,f: sys.exit(0))
srv = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind((LISTEN_HOST, LISTEN_PORT))
threading.Thread(target=cleanup, daemon=True).start()
print("[UDP Custom] Server ready.")
while True:
    try:
        data, addr = srv.recvfrom(BUFFER_SIZE)
        threading.Thread(target=handle, args=(data, addr, srv), daemon=True).start()
    except KeyboardInterrupt: break
    except Exception as e: print(f"[UDP Custom] {e}")
srv.close()
PYEOF

chmod +x "$UDPCUSTOM_SCRIPT"

cat > /etc/systemd/system/udpcustom.service << EOF
[Unit]
Description=UDP Custom Server (OPCUSTOM)
After=network.target udpgw.service
Wants=udpgw.service

[Service]
ExecStart=/usr/bin/python3 ${UDPCUSTOM_SCRIPT}
Environment=UDPCUSTOM_PORT=20000
Environment=UDPGW_PORT=7300
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable udpcustom &>/dev/null
systemctl start udpcustom
sleep 2
if systemctl is-active --quiet udpcustom; then
  ok "UDP Custom server running on port 20000"
else
  echo -e "${RED}[!]${RESET} UDP Custom failed — check: journalctl -u udpcustom -n 20"
fi

# ── Done ─────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}  ╔══════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}  ║        INSTALLATION COMPLETE!            ║${RESET}"
echo -e "${GREEN}${BOLD}  ╚══════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  ${CYAN}Services running:${RESET}"
echo -e "  • UDPGW       →  127.0.0.1:7300"
echo -e "  • UDP Custom  →  0.0.0.0:20000"
echo -e "  • Dropbear    →  port 22"
echo ""
echo -e "  ${CYAN}HTTP Custom app settings:${RESET}"
echo -e "  • SSH field   →  ${BOLD}YOUR_IP:1-65535@user:pass${RESET}"
echo -e "  • Tick        →  ${BOLD}UDP Custom${RESET}  +  ${BOLD}Enable DNS${RESET}"
echo -e "  • UDPGW set   →  ${BOLD}127.0.0.1:7300${RESET}"
echo ""
echo -e "  ${YELLOW}Launch panel:${RESET} ${BOLD}opcustom${RESET}"
echo ""
