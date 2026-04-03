#!/bin/bash
# ============================================================
#   OPCUSTOM - USER MANAGEMENT
#   Adds users to: system (Dropbear SSH) + udp-custom passwords
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
    [[ -z "$username" ]] && { echo -e "  ${R}Cannot be empty.${RESET}"; continue; }
    grep -q "^$username:" "$DB" 2>/dev/null && \
      { echo -e "  ${R}User '$username' already exists.${RESET}"; continue; }
    break
  done

  while true; do
    echo -ne "  Password: "
    read -rs password; echo ""
    [[ -z "$password" ]] && { echo -e "  ${R}Cannot be empty.${RESET}"; continue; }
    break
  done

  while true; do
    echo -ne "  Expiry days (e.g. 30): "
    read -r days
    [[ "$days" =~ ^[0-9]+$ ]] || { echo -e "  ${R}Enter a number.${RESET}"; continue; }
    break
  done

  local expiry created
  expiry=$(date -d "+${days} days" +%Y-%m-%d 2>/dev/null || \
           date -v+${days}d +%Y-%m-%d 2>/dev/null)
  created=$(date +%Y-%m-%d)

  # 1. Create Linux system user (for Dropbear SSH)
  if id "$username" &>/dev/null; then
    echo "$username:$password" | chpasswd
  else
    useradd -m -s /bin/false "$username" 2>/dev/null
    echo "$username:$password" | chpasswd
  fi

  # 2. Add to udp-custom passwords file
  udpcustom_add_user "$username" "$password"

  # 3. Save to panel DB
  echo "$username:$password:$expiry:$created" >> "$DB"

  echo ""
  echo -e "  ${G}✓ User created successfully!${RESET}"
  echo -e "  ${W}  Username : ${RESET}$username"
  echo -e "  ${W}  Password : ${RESET}$password"
  echo -e "  ${W}  Expiry   : ${RESET}$expiry"
}

# ── List Users ───────────────────────────────────────────────
list_users() {
  echo ""
  echo -e "  ${C}[ USER LIST ]${RESET}"
  echo -e "  ${W}──────────────────────────────────────────────────${RESET}"

  if [[ ! -s "$DB" ]]; then
    echo -e "  ${Y}No users found.${RESET}"
    return
  fi

  local today
  today=$(date +%Y-%m-%d)

  printf "  ${W}%-4s %-16s %-12s %-12s %-8s${RESET}\n" \
    "No." "Username" "Expiry" "Created" "Status"
  echo -e "  ${W}──────────────────────────────────────────────────${RESET}"

  local i=1
  while IFS=: read -r uname _pass expiry created _rest; do
    local sc st
    if [[ "$expiry" < "$today" ]]; then
      sc="${R}"; st="EXPIRED"
    elif [[ "$expiry" == "$today" ]]; then
      sc="${Y}"; st="TODAY"
    else
      sc="${G}"; st="ACTIVE"
    fi
    printf "  %-4s %-16s %-12s %-12s " "$i." "$uname" "$expiry" "${created:-N/A}"
    echo -e "${sc}${st}${RESET}"
    ((i++))
  done < "$DB"

  echo -e "  ${W}──────────────────────────────────────────────────${RESET}"
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
  echo -ne "  Username to delete: "
  read -r username
  [[ -z "$username" ]] && return

  if ! grep -q "^$username:" "$DB" 2>/dev/null; then
    echo -e "  ${R}User '$username' not found.${RESET}"
    return
  fi

  echo -ne "  ${R}Confirm delete '$username'? [y/N]:${RESET} "
  read -r confirm
  [[ ! "$confirm" =~ ^[Yy]$ ]] && { echo "  Cancelled."; return; }

  # Remove from panel DB
  sed -i "/^$username:/d" "$DB"

  # Remove from udp-custom passwords
  udpcustom_remove_user "$username"

  # Remove Linux system user
  userdel -r "$username" 2>/dev/null || true

  echo -e "  ${G}✓ User '$username' deleted.${RESET}"
}
