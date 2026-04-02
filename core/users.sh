#!/bin/bash
# ============================================================
#   OPCUSTOM - USER MANAGEMENT
# ============================================================

DB="$PANEL_DIR/users.db"

# ── Add User ─────────────────────────────────────────────────
add_user() {
  echo ""
  echo -e "  ${C}[ ADD USER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  while true; do
    echo -ne "  Username: "
    read -r username
    [[ -z "$username" ]] && { echo -e "  ${R}Username cannot be empty.${RESET}"; continue; }
    if grep -q "^$username:" "$DB" 2>/dev/null; then
      echo -e "  ${R}User '$username' already exists.${RESET}"; continue
    fi
    break
  done

  while true; do
    echo -ne "  Password: "
    read -rs password; echo ""
    [[ -z "$password" ]] && { echo -e "  ${R}Password cannot be empty.${RESET}"; continue; }
    break
  done

  while true; do
    echo -ne "  Expiry days (e.g. 30): "
    read -r days
    [[ "$days" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Enter a number.${RESET}"; continue; }
    break
  done

  local expiry
  expiry=$(date -d "+${days} days" +%Y-%m-%d 2>/dev/null || \
           date -v+${days}d +%Y-%m-%d 2>/dev/null)

  # Create system user for Dropbear SSH auth
  if id "$username" &>/dev/null; then
    echo -ne "  ${Y}System user exists — update password? [y/N]:${RESET} "
    read -r ans
    [[ "$ans" =~ ^[Yy]$ ]] && echo "$username:$password" | chpasswd
  else
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
  fi

  # Save to DB: username:password:expiry:created
  local created
  created=$(date +%Y-%m-%d)
  echo "$username:$password:$expiry:$created" >> "$DB"

  echo ""
  echo -e "  ${G}✓ User created successfully!${RESET}"
  echo -e "  ${W}  Username : ${RESET}$username"
  echo -e "  ${W}  Password : ${RESET}$password"
  echo -e "  ${W}  Expiry   : ${RESET}$expiry"
  echo -e "  ${W}  Port     : ${RESET}$(dropbearconfig 2>/dev/null | grep -oP '(?<=port )\d+' | head -1 || echo 22)"
}

# ── List Users ───────────────────────────────────────────────
list_users() {
  echo ""
  echo -e "  ${C}[ USER LIST ]${RESET}"
  echo -e "  ${W}────────────────────────────────────────────────────${RESET}"

  if [[ ! -s "$DB" ]]; then
    echo -e "  ${Y}No users found.${RESET}"
    return
  fi

  local today
  today=$(date +%Y-%m-%d)

  printf "  ${W}%-4s %-16s %-12s %-12s %-8s${RESET}\n" "No." "Username" "Expiry" "Created" "Status"
  echo -e "  ${W}────────────────────────────────────────────────────${RESET}"

  local i=1
  while IFS=: read -r uname _pass expiry created _rest; do
    local status_color status_text
    if [[ "$expiry" < "$today" ]]; then
      status_color="${R}"; status_text="EXPIRED"
    elif [[ "$expiry" == "$today" ]]; then
      status_color="${Y}"; status_text="TODAY"
    else
      status_color="${G}"; status_text="ACTIVE"
    fi
    printf "  %-4s %-16s %-12s %-12s " "$i." "$uname" "$expiry" "${created:-N/A}"
    echo -e "${status_color}${status_text}${RESET}"
    ((i++))
  done < "$DB"
  echo -e "  ${W}────────────────────────────────────────────────────${RESET}"
  echo -e "  Total: $((i-1)) user(s)"
}

# ── Delete User ──────────────────────────────────────────────
delete_user() {
  echo ""
  echo -e "  ${C}[ DELETE USER ]${RESET}"
  echo -e "  ${W}────────────────────────────────────${RESET}"

  if [[ ! -s "$DB" ]]; then
    echo -e "  ${Y}No users to delete.${RESET}"
    return
  fi

  list_users

  echo ""
  echo -ne "  Enter username to delete: "
  read -r username
  [[ -z "$username" ]] && return

  if ! grep -q "^$username:" "$DB" 2>/dev/null; then
    echo -e "  ${R}User '$username' not found.${RESET}"
    return
  fi

  echo -ne "  ${R}Confirm delete '$username'? [y/N]:${RESET} "
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { echo "  Cancelled."; return; }

  # Remove from DB
  sed -i "/^$username:/d" "$DB"

  # Remove system user
  userdel -r "$username" 2>/dev/null || true

  echo -e "  ${G}✓ User '$username' deleted.${RESET}"
}
