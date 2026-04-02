#!/bin/bash

MAX=1

for user in $(cut -d: -f1 /root/opcustom/users.db); do
COUNT=$(ps aux | grep $user | grep -v grep | wc -l)

if [ "$COUNT" -gt "$MAX" ]; then
pkill -u $user
echo "Killed multi-login: $user"
fi
done
