#!/bin/bash

# Number of users to create
NUM_USERS=50

# OpenVPN script location
SCRIPT="./openvpn-install.sh"

# Check if script exists
if [ ! -f "$SCRIPT" ]; then
    echo "Error: OpenVPN installation script not found!"
    exit 1
fi

# Loop to create users
for i in $(seq 1 $NUM_USERS); do
    USERNAME="user$i"
    echo -e "1\n$USERNAME" | $SCRIPT
    echo "Created user: $USERNAME"
done

echo "All $NUM_USERS users created successfully."