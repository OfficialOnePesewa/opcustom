#!/bin/bash

case $1 in

start)
screen -dmS udp badvpn-udpgw --listen-addr 0.0.0.0:7300
echo "UDPGW started on port 7300"
;;

stop)
pkill badvpn-udpgw
echo "UDPGW stopped"
;;

esac
