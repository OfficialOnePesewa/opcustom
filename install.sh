#!/bin/bash

clear
echo "🚀 OPCUSTOM PANEL INSTALLER"

apt update -y
apt install -y git curl wget unzip screen dropbear build-essential cmake make gcc

systemctl enable dropbear
systemctl restart dropbear

# Install BadVPN
cd /root
rm -rf badvpn
git clone https://github.com/ambrop72/badvpn.git
cd badvpn
mkdir build && cd build
cmake .. -DBUILD_NOTHING_BY_DEFAULT=1 -DBUILD_UDPGW=1
make install

# Install panel
cd /root
rm -rf opcustom
git clone https://github.com/OfficialOnePesewa/opcustom.git
cd opcustom

chmod +x *.sh
chmod +x core/*.sh

touch users.db

ln -sf /root/opcustom/menu.sh /usr/bin/opcustom

echo "✅ INSTALL COMPLETE"
echo "👉 Run: opcustom"
