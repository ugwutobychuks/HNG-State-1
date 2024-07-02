Bash Script: create_users.sh
bash

#!/bin/bash

# Log file
LOGFILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Ensure log and password files exist
touch $LOGFILE
touch $PASSWORD_FILE

# Function to generate random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Read input file line by line
while IFS=';' read -r username groups; do
    # Remove any leading/trailing whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)
    
    # Skip empty lines
    if [[ -z "$username" ]]; then
        continue
    fi

    # Create personal group for the user
    if ! getent group "$username" > /dev/null 2>&1; then
        groupadd "$username"
        echo "$(date): Created group $username" >> $LOGFILE
    fi

    # Create user with the personal group
    if ! id "$username" > /dev/null 2>&1; then
        useradd -m -g "$username" -s /bin/bash "$username"
        echo "$(date): Created user $username" >> $LOGFILE
    else
        echo "$(date): User $username already exists" >> $LOGFILE
        continue
    fi

    # Add user to additional groups
    if [[ -n "$groups" ]]; then
        IFS=',' read -r -a group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            group=$(echo "$group" | xargs)
            if ! getent group "$group" > /dev/null 2>&1; then
                groupadd "$group"
                echo "$(date): Created group $group" >> $LOGFILE
            fi
            usermod -aG "$group" "$username"
            echo "$(date): Added $username to group $group" >> $LOGFILE
        done
    fi

    # Generate and store password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> $PASSWORD_FILE
    echo "$(date): Set password for $username" >> $LOGFILE

    # Set permissions
    chmod 700 /home/$username
    chown $username:$username /home/$username
    echo "$(date): Set permissions for /home/$username" >> $LOGFILE

done < "$1"

echo "User creation completed. Check $LOGFILE for details."
