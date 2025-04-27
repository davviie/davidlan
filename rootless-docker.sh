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

# Function to reinstall AppArmor and create the Docker profile
reinstall_apparmor_and_setup_profile() {
    echo "Reinstalling AppArmor and setting up the Docker profile..."

    # Reinstall AppArmor
    echo "Reinstalling AppArmor..."
    sudo apt-get update
    sudo apt-get install --yes apparmor apparmor-utils
    sudo systemctl enable apparmor.service
    sudo systemctl start apparmor.service
    print_status $? "AppArmor reinstalled successfully."

    # Verify AppArmor status
    if ! sudo aa-status >/dev/null 2>&1; then
        print_status 1 "AppArmor is not running. Please check manually."
        exit 1
    else
        print_status 0 "AppArmor is running."
    fi

    # Create the AppArmor profile for rootlesskit
    echo "Creating the AppArmor profile for rootlesskit..."
    local filename=$(echo "$HOME/bin/rootlesskit" | sed -e 's@^/@@' -e 's@/@.@g')

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

    # Restart AppArmor to apply the new profile
    echo "Restarting the AppArmor service..."
    sudo systemctl restart apparmor.service
    print_status $? "AppArmor service restarted successfully."

    # Verify that the profile is loaded
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

# Function to verify pam_systemd configuration
verify_pam_systemd() {
    echo "Verifying pam_systemd configuration..."
    for file in /etc/pam.d/common-session /etc/pam.d/common-session-noninteractive; do
        if [ ! -f "$file" ]; then
            print_status 1 "$file does not exist. Creating it..."
            echo "# PAM configuration for $file" | sudo tee "$file"
            print_status $? "$file created."
        fi

        if ! grep -q pam_systemd "$file"; then
            print_status 1 "pam_systemd is not configured in $file. Adding it..."
            echo "session optional pam_systemd.so" | sudo tee -a "$file"
            print_status $? "pam_systemd added to $file."
        else
            print_status 0 "pam_systemd is properly configured in $file."
        fi
    done
}

# Function to verify systemd-logind service
verify_systemd_logind() {
    echo "Verifying systemd-logind service..."
    if ! systemctl is-active systemd-logind >/dev/null 2>&1; then
        print_status 1 "systemd-logind service is not active. Restarting..."
        sudo systemctl restart systemd-logind
        print_status $? "systemd-logind service restarted successfully."
    else
        print_status 0 "systemd-logind service is active."
    fi
}

# Function to manually register user session
manually_register_user_session() {
    echo "Manually registering user session..."
    if ! loginctl list-sessions | grep -q $USER; then
        print_status 1 "User session for $USER is not registered. Registering manually..."
        sudo loginctl create-session $USER
        print_status $? "User session for $USER registered manually."
    else
        print_status 0 "User session for $USER is already registered."
    fi
}

# Function to debug systemd-machined
debug_systemd_machined() {
    echo "Debugging systemd-machined..."
    if ! systemctl is-active systemd-machined >/dev/null 2>&1; then
        print_status 1 "systemd-machined service is not active. Restarting..."
        sudo systemctl restart systemd-machined
        print_status $? "systemd-machined service restarted successfully."
    else
        print_status 0 "systemd-machined service is active."
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
reinstall_apparmor_and_setup_profile
install_docker_rootless_extras
verify_kernel_userns_support
verify_unprivileged_userns_clone
verify_proc_access
verify_lingering_and_user_session
verify_pam_systemd
verify_systemd_logind
manually_register_user_session
debug_systemd_machined
start_rootless_docker

echo -e "\e[32mRootless Docker installation and configuration completed successfully!\e[0m"