#!/bin/bash

source /root/opcustom/core/lib.sh

while true; do
clear
echo "======================================"
echo "      OPCUSTOM UDP PANEL"
echo "======================================"
echo "1. Add User"
echo "2. List Users"
echo "3. Delete User"
echo "4. Start UDPGW"
echo "5. Stop UDPGW"
echo "6. Monitor Connections"
echo "0. Exit"
echo "======================================"
read -p "Select: " opt

case $opt in
1) bash /root/opcustom/core/users.sh add ;;
2) bash /root/opcustom/core/users.sh list ;;
3) bash /root/opcustom/core/users.sh delete ;;
4) bash /root/opcustom/core/service.sh start ;;
5) bash /root/opcustom/core/service.sh stop ;;
6) bash /root/opcustom/core/monitor.sh ;;
0) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac
done
