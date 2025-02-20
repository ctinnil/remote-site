#!/bin/bash

# Check if the openvpn-install.sh script exists
OPENVPN_SCRIPT="/mnt/data/openvpn-install.sh"
if [[ ! -f "$OPENVPN_SCRIPT" ]]; then
    echo "Error: OpenVPN installation script not found at $OPENVPN_SCRIPT."
    exit 1
fi

# Function to generate a random 12-character password
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*()_+-=' </dev/urandom | head -c 12
}

# Get user input for the number of users
read -p "Enter the number of OpenVPN users to create: " USER_COUNT
read -p "Enter the base username (e.g., vpnuser): " BASE_NAME
read -p "Use randomly generated passwords? (yes/no): " USE_PASSWORDS

# Validate input
if ! [[ "$USER_COUNT" =~ ^[0-9]+$ ]]; then
    echo "Error: Please enter a valid number of users."
    exit 1
fi

# Prepare CSV output file
CSV_FILE="openvpn_users.csv"
echo "Username,Password" > "$CSV_FILE"

# Loop to create users
for i in $(seq 1 $USER_COUNT); do
    USERNAME="${BASE_NAME}${i}"
    PASSWORD=""
    if [[ "$USE_PASSWORDS" =~ ^[Yy][Ee][Ss]$ ]]; then
        PASSWORD=$(generate_password)
        echo "Generated password for $USERNAME: $PASSWORD"
    fi

    echo "Creating OpenVPN user: $USERNAME"
    echo -e "${USERNAME}\n${PASSWORD}" | sudo bash "$OPENVPN_SCRIPT"
    
    # Save to CSV file
    echo "$USERNAME,$PASSWORD" >> "$CSV_FILE"
done

echo "All users created successfully. User details saved to $CSV_FILE."
