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

# Function to verify kernel support for user namespaces
verify_kernel_userns_support() {
    echo "Verifying kernel support for user namespaces..."
    if ! zgrep -q CONFIG_USER_NS=y /proc/config.gz; then
        print_status 1 "Kernel does not support user namespaces. Please enable CONFIG_USER_NS in the kernel."
        exit 1
    else
        print_status 0 "Kernel supports user namespaces."
    fi
}

# Function to verify unprivileged user namespace cloning
verify_unprivileged_userns_clone() {
    echo "Verifying unprivileged user namespace cloning..."
    if [ "$(cat /proc/sys/kernel/unprivileged_userns_clone)" -ne 1 ]; then
        print_status 1 "Unprivileged user namespaces are disabled. Enabling temporarily..."
        sudo sysctl kernel.unprivileged_userns_clone=1
        print_status $? "Unprivileged user namespaces enabled temporarily."
    else
        print_status 0 "Unprivileged user namespaces are already enabled."
    fi
}

# Function to verify /proc accessibility
verify_proc_access() {
    echo "Verifying /proc accessibility..."
    if ! mount | grep -q "proc on /proc"; then
        print_status 1 "/proc is not mounted. Attempting to remount..."
        sudo mount -t proc proc /proc
        print_status $? "/proc successfully remounted."
    else
        print_status 0 "/proc is properly mounted."
    fi
}

# Function to verify lingering and user session
verify_lingering_and_user_session() {
    echo "Verifying lingering and user session..."
    if ! loginctl show-user $USER | grep -q "Linger=yes"; then
        print_status 1 "Lingering is not enabled for $USER. Enabling lingering..."
        sudo loginctl enable-linger $USER
        print_status $? "Lingering enabled for $USER. Please reboot and re-run the script."
        exit 1
    else
        print_status 0 "Lingering is enabled for $USER."
    fi

    echo "Checking user@1000.service..."
    if ! systemctl --user is-active user@1000.service >/dev/null 2>&1; then
        print_status 1 "user@1000.service is not active. Restarting..."
        sudo systemctl restart user-1000.slice
        print_status $? "user@1000.service restarted successfully."
    else
        print_status 0 "user@1000.service is active."
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
verify_kernel_userns_support
verify_unprivileged_userns_clone
verify_proc_access
verify_lingering_and_user_session
debug_newuidmap
start_rootless_docker

echo -e "\e[32mRootless Docker installation and configuration completed successfully!\e[0m"