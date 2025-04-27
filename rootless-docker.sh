#!/bin/bash

# Function to print PASS/FAIL messages
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "\e[32m[PASS]\e[0m $2"
    else
        echo -e "\e[31m[FAIL]\e[0m $2"
    fi
}

# Prevent running the script with sudo
if [ "$EUID" -eq 0 ]; then
    echo -e "\e[31m[FAIL]\e[0m Do not run this script with sudo or as root. Exiting."
    exit 1
fi

# Function to install dependencies
install_dependencies() {
    echo "Installing required dependencies..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common \
        gnupg \
        lsb-release \
        dbus-user-session \
        uidmap \
        slirp4netns \
        fuse-overlayfs \
        systemd-container
    print_status $? "All required dependencies installed."
}

# Function to configure /etc/subuid and /etc/subgid
configure_subuid_subgid() {
    echo "Configuring /etc/subuid and /etc/subgid for $USER..."
    local UID_RANGE_START=100000
    local UID_RANGE_COUNT=65536

    for file in /etc/subuid /etc/subgid; do
        if ! grep -q "^$USER:" "$file"; then
            echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee -a "$file"
            print_status $? "$file configured for $USER."
        else
            local CURRENT_RANGE=$(grep "^$USER:" "$file" | awk -F: '{print $2":"$3}')
            if [ "$CURRENT_RANGE" != "$UID_RANGE_START:$UID_RANGE_COUNT" ]; then
                echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee "$file"
                print_status $? "$file updated for $USER."
            else
                print_status 0 "$file is already correctly configured for $USER."
            fi
        fi
    done
}

# Function to check and create the AppArmor profile for rootlesskit
setup_apparmor_profile() {
    echo "Setting up the AppArmor profile for rootlesskit..."
    local filename=$(echo "$HOME/bin/rootlesskit" | sed -e 's@^/@@' -e 's@/@.@g')

    if [ ! -f /etc/apparmor.d/${filename} ]; then
        echo "Creating the AppArmor profile for rootlesskit..."
        cat <<EOF > ~/${filename}
abi <abi/4.0>,
include <tunables/global>

"$HOME/bin/rootlesskit" flags=(unconfined) {
  userns,

  include if exists <local/${filename}>
}
EOF
        sudo mv ~/${filename} /etc/apparmor.d/${filename}
        print_status $? "AppArmor profile created and moved to /etc/apparmor.d/${filename}."
    else
        print_status 0 "AppArmor profile for rootlesskit already exists."
    fi

    echo "Restarting the AppArmor service..."
    sudo systemctl restart apparmor.service
    print_status $? "AppArmor service restarted successfully."

    if sudo aa-status | grep -q rootlesskit; then
        print_status 0 "AppArmor profile for rootlesskit is loaded."
    else
        print_status 1 "Failed to load AppArmor profile for rootlesskit. Please check manually."
        exit 1
    fi
}

# Function to verify and install docker-ce-rootless-extras
install_docker_rootless_extras() {
    echo "Checking if docker-ce-rootless-extras is installed..."
    if ! dpkg -l | grep -q docker-ce-rootless-extras; then
        print_status 1 "docker-ce-rootless-extras is not installed. Installing..."
        sudo apt-get install -y docker-ce-rootless-extras
        print_status $? "docker-ce-rootless-extras installed."
    else
        print_status 0 "docker-ce-rootless-extras is already installed."
    fi
}

# Function to test newuidmap and newgidmap
test_newuidmap_newgidmap() {
    echo "Testing newuidmap and newgidmap..."
    if ! newuidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
        print_status 1 "newuidmap test failed. Collecting debugging information..."
        strace -e openat newuidmap 1000 0 1000 1 1 100000 65536 2>&1 | tee newuidmap_debug.log
        echo "Debugging information saved to newuidmap_debug.log"
        exit 1
    else
        print_status 0 "newuidmap test passed."
    fi

    if ! newgidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
        print_status 1 "newgidmap test failed. Collecting debugging information..."
        strace -e openat newgidmap 1000 0 1000 1 1 100000 65536 2>&1 | tee newgidmap_debug.log
        echo "Debugging information saved to newgidmap_debug.log"
        exit 1
    else
        print_status 0 "newgidmap test passed."
    fi
}

# Function to start the rootless Docker service
start_rootless_docker() {
    echo "Starting the rootless Docker service..."
    if [ ! -f ~/.config/systemd/user/docker.service ]; then
        dockerd-rootless-setuptool.sh install || {
            print_status 1 "Failed to install rootless Docker service."
            exit 1
        }
        print_status $? "Rootless Docker service installed."
    else
        print_status 0 "Rootless Docker service already installed."
    fi

    systemctl --user daemon-reload
    if ! systemctl --user start docker; then
        print_status 1 "Failed to start rootless Docker service. Collecting logs..."
        journalctl --user -xeu docker.service | tail -n 20
        exit 1
    else
        print_status 0 "Rootless Docker service started successfully."
    fi
}

# Main script execution
install_dependencies
configure_subuid_subgid
setup_apparmor_profile
install_docker_rootless_extras
test_newuidmap_newgidmap
start_rootless_docker

echo -e "\e[32mRootless Docker installation and configuration completed successfully!\e[0m"