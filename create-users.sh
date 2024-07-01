#!/bin/bash

# create folders for logs and secure passwords
mkdir -p /var/log /var/secure

# create logs file and passwords file
touch /var/log/user_management.log
touch /var/secure/user_passwords.txt

# make password file secure (read and write permissions for file owner only)

chmod 600 /var/secure/user_passwords.txt

# function to log actions to log file
log_action() {
    echo "$(date) - $1" >> "/var/log/user_management.log"
}


create_user() {

    # defines 3 variables passed to the function: user, groups, and password
    local user="$1"
    local groups="$2"
    local password

    # check if user already exists by logging user information with id

    if id "$user" &>/dev/null; then
        log_action "User $user already exists."
        return
    fi

    # Create personal group for the user
    groupadd "$user"

    # Create additional groups if they do not exist
    IFS=' ' read -ra group_array <<< "$groups"

    # Log the group array
    log_action "User $user will be added to groups: ${group_array[*]}"

    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)  # Trim whitespace
        if ! getent group "$group" &>/dev/null; then
            groupadd "$group"
            log_action "Group $group created."
        fi
    done

    # Create user with home directory and shell, primary group set to the personal group
    useradd -m -s /bin/bash -g "$user" "$user"
    if [ $? -eq 0 ]; then
        log_action "User $user created with primary group: $user"
    else
        log_action "Failed to create user $user."
        return
    fi

    # Add the user to additional groups
    for group in "${group_array[@]}"; do
        usermod -aG "$group" "$user"
    done
    log_action "User $user added to groups: ${group_array[*]}"

    # generate password and store it securely in a file
    password=$(</dev/urandom tr -dc A-Za-z0-9 | head -c 12)
    echo "$user:$password" | chpasswd

    # store user and password securely in a file
    echo "$user,$password" >> "/var/secure/user_passwords.txt"

    # set permissions and ownership for user home directory
    chmod 700 "/home/$user"
    chown "$user:$user" "/home/$user"

    log_action "Password for user $user set and stored securely."
}

# check if user list file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <user_list_file>"
    exit 1
fi

filename="$1"

if [ ! -f "$filename" ]; then
    echo "Users list file $filename not found."
    exit 1
fi

# read user list file and create users
while IFS=';' read -r user groups; do
    user=$(echo "$user" | xargs)
    groups=$(echo "$groups" | xargs | tr -d ' ')

    # Replace commas with spaces for usermod group format
    groups=$(echo "$groups" | tr ',' ' ')
    create_user "$user" "$groups"
done < "$filename"

echo "User creation process completed. Check /var/log/user_management.log for details."