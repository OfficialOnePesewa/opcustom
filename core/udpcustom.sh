#!/bin/bash
# ============================================================
#   OPCUSTOM - UDP CUSTOM SERVER
#   Listens on port 20000, forwards through UDPGW :7300
# ============================================================

UDPCUSTOM_PORT=20000
UDPCUSTOM_SERVICE="udpcustom"
UDPCUSTOM_SCRIPT="/usr/local/bin/udpcustom-server"

# ── Install UDP Custom Server ────────────────────────────────
install_udpcustom() {
  echo ""
  echo -e "  ${C}[ INSTALLING UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  # Write the UDP Custom server Python script
  cat > "$UDPCUSTOM_SCRIPT" << 'PYEOF'
#!/usr/bin/env python3
"""
UDP Custom Server for HTTP Custom VPN app
Accepts UDP connections and tunnels through BadVPN UDPGW
"""
import socket
import threading
import struct
import sys
import os
import signal
import time

LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(os.environ.get("UDPCUSTOM_PORT", 20000))
UDPGW_HOST  = "127.0.0.1"
UDPGW_PORT  = int(os.environ.get("UDPGW_PORT", 7300))
BUFFER_SIZE = 65535
TIMEOUT     = 120  # seconds

print(f"[UDP Custom] Listening on {LISTEN_HOST}:{LISTEN_PORT}")
print(f"[UDP Custom] Forwarding to UDPGW {UDPGW_HOST}:{UDPGW_PORT}")

clients = {}
clients_lock = threading.Lock()

def handle_client(data, addr, server_sock):
    key = addr
    with clients_lock:
        if key not in clients:
            try:
                gw_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                gw_sock.settimeout(TIMEOUT)
                gw_sock.connect((UDPGW_HOST, UDPGW_PORT))
                clients[key] = {"sock": gw_sock, "last": time.time()}

                def relay_back(gw, client_addr, srv):
                    try:
                        while True:
                            resp = gw.recv(BUFFER_SIZE)
                            if not resp:
                                break
                            # Strip badvpn-udpgw 2-byte length header if present
                            if len(resp) > 2:
                                length = struct.unpack(">H", resp[:2])[0]
                                payload = resp[2:2+length] if length <= len(resp)-2 else resp[2:]
                            else:
                                payload = resp
                            srv.sendto(payload, client_addr)
                    except Exception:
                        pass
                    finally:
                        with clients_lock:
                            if client_addr in clients:
                                try: clients[client_addr]["sock"].close()
                                except: pass
                                del clients[client_addr]

                t = threading.Thread(target=relay_back, args=(gw_sock, addr, server_sock), daemon=True)
                t.start()
            except Exception as e:
                print(f"[UDP Custom] GW connect failed: {e}")
                return
        else:
            clients[key]["last"] = time.time()

    with clients_lock:
        gw_sock = clients.get(key, {}).get("sock")

    if gw_sock:
        try:
            # Prepend 2-byte length for badvpn-udpgw framing
            frame = struct.pack(">H", len(data)) + data
            gw_sock.sendall(frame)
        except Exception as e:
            print(f"[UDP Custom] Send error: {e}")
            with clients_lock:
                if key in clients:
                    try: clients[key]["sock"].close()
                    except: pass
                    del clients[key]

def cleanup_idle():
    while True:
        time.sleep(30)
        now = time.time()
        with clients_lock:
            stale = [k for k, v in clients.items() if now - v["last"] > TIMEOUT]
            for k in stale:
                try: clients[k]["sock"].close()
                except: pass
                del clients[k]
        if stale:
            print(f"[UDP Custom] Cleaned {len(stale)} idle client(s)")

def main():
    signal.signal(signal.SIGTERM, lambda s, f: sys.exit(0))
    server = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, LISTEN_PORT))

    threading.Thread(target=cleanup_idle, daemon=True).start()

    print(f"[UDP Custom] Server ready.")
    while True:
        try:
            data, addr = server.recvfrom(BUFFER_SIZE)
            threading.Thread(target=handle_client, args=(data, addr, server), daemon=True).start()
        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"[UDP Custom] Error: {e}")

    server.close()

if __name__ == "__main__":
    main()
PYEOF

  chmod +x "$UDPCUSTOM_SCRIPT"

  # Create systemd service
  cat > /etc/systemd/system/${UDPCUSTOM_SERVICE}.service << EOF
[Unit]
Description=UDP Custom Server (OPCUSTOM)
After=network.target udpgw.service
Wants=udpgw.service

[Service]
ExecStart=/usr/bin/python3 ${UDPCUSTOM_SCRIPT}
Environment=UDPCUSTOM_PORT=${UDPCUSTOM_PORT}
Environment=UDPGW_PORT=7300
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable "$UDPCUSTOM_SERVICE" &>/dev/null
  systemctl restart "$UDPCUSTOM_SERVICE"
  sleep 2

  if systemctl is-active --quiet "$UDPCUSTOM_SERVICE"; then
    echo -e "  ${G}✓ UDP Custom server running on port ${UDPCUSTOM_PORT}${RESET}"
  else
    echo -e "  ${R}✗ Failed to start. Check: journalctl -u $UDPCUSTOM_SERVICE -n 20${RESET}"
  fi
}

# ── Start ────────────────────────────────────────────────────
start_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if ! [[ -f "$UDPCUSTOM_SCRIPT" ]]; then
    echo -e "  ${Y}Not installed. Installing now...${RESET}"
    install_udpcustom
    return
  fi

  if systemctl is-active --quiet "$UDPCUSTOM_SERVICE"; then
    echo -e "  ${Y}UDP Custom already running on port ${UDPCUSTOM_PORT}.${RESET}"
    return
  fi

  systemctl start "$UDPCUSTOM_SERVICE"
  sleep 1
  if systemctl is-active --quiet "$UDPCUSTOM_SERVICE"; then
    echo -e "  ${G}✓ UDP Custom started on port ${UDPCUSTOM_PORT}${RESET}"
  else
    echo -e "  ${R}✗ Start failed. Run: journalctl -u $UDPCUSTOM_SERVICE -n 20${RESET}"
  fi
}

# ── Stop ─────────────────────────────────────────────────────
stop_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM SERVER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"
  systemctl stop "$UDPCUSTOM_SERVICE" 2>/dev/null
  echo -e "  ${G}✓ UDP Custom stopped.${RESET}"
}

# ── Status ───────────────────────────────────────────────────
status_udpcustom() {
  echo ""
  echo -e "  ${C}[ UDP CUSTOM STATUS ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if systemctl is-active --quiet "$UDPCUSTOM_SERVICE" 2>/dev/null; then
    echo -e "  Service  : ${G}RUNNING${RESET}"
  else
    echo -e "  Service  : ${R}STOPPED${RESET}"
  fi

  echo -e "  Port     : ${UDPCUSTOM_PORT} (UDP)"
  echo -e "  UDPGW    : 127.0.0.1:7300"

  local pid
  pid=$(pgrep -f "udpcustom-server" | head -1)
  [[ -n "$pid" ]] && echo -e "  PID      : $pid"

  echo ""
  echo -e "  ${W}Recent logs:${RESET}"
  journalctl -u "$UDPCUSTOM_SERVICE" -n 8 --no-pager 2>/dev/null | sed 's/^/    /' || echo "  (no logs)"
}

# ── Generate Client String ───────────────────────────────────
generate_client_string() {
  echo ""
  echo -e "  ${C}[ CLIENT CONNECTION STRING ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  local ip
  ip=$(curl -s --max-time 4 ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

  if [[ ! -s "$PANEL_DIR/users.db" ]]; then
    echo -e "  ${Y}No users found. Add a user first.${RESET}"
    return
  fi

  echo -e "  ${W}Select user:${RESET}"
  local i=1
  local users=()
  while IFS=: read -r uname pass expiry _rest; do
    echo -e "  ${Y}${i}.${RESET} $uname (expires: $expiry)"
    users+=("$uname:$pass")
    ((i++))
  done < "$PANEL_DIR/users.db"

  echo ""
  echo -ne "  Choice: "
  read -r sel
  [[ ! "$sel" =~ ^[0-9]+$ ]] && return
  local entry="${users[$((sel-1))]}"
  [[ -z "$entry" ]] && { echo -e "  ${R}Invalid selection.${RESET}"; return; }

  local uname pass
  uname=$(echo "$entry" | cut -d: -f1)
  pass=$(echo "$entry" | cut -d: -f2)

  echo ""
  echo -e "  ${W}╔══════════════════════════════════════════╗${RESET}"
  echo -e "  ${W}║       HTTP CUSTOM CONNECTION INFO        ║${RESET}"
  echo -e "  ${W}╠══════════════════════════════════════════╣${RESET}"
  echo -e "  ${W}║${RESET}  Server IP : ${G}${ip}${RESET}"
  echo -e "  ${W}║${RESET}  Port      : ${G}1-65535${RESET}"
  echo -e "  ${W}║${RESET}  Username  : ${G}${uname}${RESET}"
  echo -e "  ${W}║${RESET}  Password  : ${G}${pass}${RESET}"
  echo -e "  ${W}║${RESET}  UDP GW    : ${G}127.0.0.1:7300${RESET}"
  echo -e "  ${W}║${RESET}  Mode      : ${G}UDP Custom${RESET}"
  echo -e "  ${W}╚══════════════════════════════════════════╝${RESET}"
  echo ""
  echo -e "  ${C}SSH String:${RESET}"
  echo -e "  ${G}${ip}:1-65535@${uname}:${pass}${RESET}"
}
