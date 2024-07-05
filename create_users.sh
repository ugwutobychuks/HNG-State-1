#!/bin/bash

# Check if the file is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: sudo bash create_users.sh <name-of-text-file>"
  exit 1
fi

# File containing usernames and groups
USER_FILE="$1"

# Log file for user management actions
LOG_FILE="/Users/jade/sysops/var/log/user_management.log"
# File to store generated passwords
PASSWORD_FILE="/Users/jade/sysops/var/secure/user_passwords.txt"

# Ensure the log directory exists
mkdir -p /Users/jade/sysops/var/log
# Ensure the secure directory exists
mkdir -p /Users/jade/sysops/var/secure

# Ensure the log file exists
touch $LOG_FILE
# Ensure the password file exists and set appropriate permissions
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Full paths to the commands
GROUPADD="/usr/sbin/groupadd"
USERADD="/usr/sbin/useradd"
CHPASSWD="/usr/sbin/chpasswd"
USERMOD="/usr/sbin/usermod"

# Function to generate a random password
generate_password() {
  local PASSWORD=$(openssl rand -base64 12)
  echo $PASSWORD
}

# Validate username and group
validate_name() {
  local NAME=$1
  if [[ ! "$NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "Invalid name: $NAME" | tee -a $LOG_FILE
    exit 1
  fi
}

# Read the user file line by line
while IFS=";" read -r username groups; do
  # Remove whitespace
  username=$(echo "$username" | xargs)
  groups=$(echo "$groups" | xargs)

  # Validate username
  validate_name "$username"

  # Create user-specific group
  if ! getent group "$username" > /dev/null 2>&1; then
    $GROUPADD "$username"
    echo "Group $username created" | tee -a $LOG_FILE
  else
    echo "Group $username already exists" | tee -a $LOG_FILE
  fi

  # Check if user exists
  if ! id -u "$username" > /dev/null 2>&1; then
    # Generate password
    password=$(generate_password)

    # Create the user with their own group and home directory
    $USERADD -m -g "$username" -s /bin/bash "$username"
    echo "$username:$password" | $CHPASSWD
    echo "User $username created with home directory and assigned to group $username" | tee -a $LOG_FILE

    # Set appropriate permissions for home directory
    chmod 700 /home/"$username"
    chown "$username:$username" /home/"$username"

    # Log the password securely
    echo "$username,$password" >> $PASSWORD_FILE
  else
    echo "User $username already exists" | tee -a $LOG_FILE
  fi

  # Add user to additional groups
  if [ ! -z "$groups" ]; then
    IFS=',' read -ra ADDR <<< "$groups"
    for group in "${ADDR[@]}"; do
      group=$(echo "$group" | xargs) # Remove whitespace
      validate_name "$group"
      if ! getent group "$group" > /dev/null 2>&1; then
        $GROUPADD "$group"
        echo "Group $group created" | tee -a $LOG_FILE
      fi
      $USERMOD -aG "$group" "$username"
      echo "User $username added to group $group" | tee -a $LOG_FILE
    done
  fi
done < "$USER_FILE"
