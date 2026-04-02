#!/bin/bash

DB="/root/opcustom/users.db"

case $1 in

add)
read -p "Username: " user
read -p "Password: " pass

echo "$user:$pass" >> $DB
echo "User added!"
;;

list)
cat $DB
;;

delete)
read -p "Username: " user
grep -v "^$user:" $DB > temp && mv temp $DB
echo "Deleted!"
;;

esac
