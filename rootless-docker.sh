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

# Update package database
sudo apt-get update

# Install required dependencies
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add the Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package database again
sudo apt-get update

# Verify and configure /etc/subuid and /etc/subgid for the current user
echo "Verifying /etc/subuid and /etc/subgid configuration for $USER..."

# Define the required UID/GID mapping range
UID_RANGE_START=100000
UID_RANGE_COUNT=65536

# Check and configure /etc/subuid
if ! grep -q "^$USER:" /etc/subuid; then
    echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee -a /etc/subuid
    print_status $? "/etc/subuid configured for $USER."
else
    CURRENT_SUBUID=$(grep "^$USER:" /etc/subuid | awk -F: '{print $2":"$3}')
    if [ "$CURRENT_SUBUID" != "$UID_RANGE_START:$UID_RANGE_COUNT" ]; then
        echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee /etc/subuid
        print_status $? "/etc/subuid updated for $USER."
    else
        print_status 0 "/etc/subuid is already correctly configured for $USER."
    fi
fi

# Check and configure /etc/subgid
if ! grep -q "^$USER:" /etc/subgid; then
    echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee -a /etc/subgid
    print_status $? "/etc/subgid configured for $USER."
else
    CURRENT_SUBGID=$(grep "^$USER:" /etc/subgid | awk -F: '{print $2":"$3}')
    if [ "$CURRENT_SUBGID" != "$UID_RANGE_START:$UID_RANGE_COUNT" ]; then
        echo "$USER:$UID_RANGE_START:$UID_RANGE_COUNT" | sudo tee /etc/subgid
        print_status $? "/etc/subgid updated for $USER."
    else
        print_status 0 "/etc/subgid is already correctly configured for $USER."
    fi
fi

# Ensure permissions for newuidmap and newgidmap
echo "Checking permissions for newuidmap and newgidmap..."
sudo chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap
print_status $? "Permissions for newuidmap and newgidmap are correctly set."

# Install dbus-user-session package if not installed
echo "Checking if dbus-user-session is installed..."
sudo apt-get install -y dbus-user-session
print_status $? "dbus-user-session is installed."

# Install uidmap package if not installed
echo "Checking if uidmap is installed..."
sudo apt-get install -y uidmap
print_status $? "uidmap is installed."

# Test if user is directly logged in or needs machinectl
echo "Testing login session type..."
if [ -z "$XDG_SESSION_TYPE" ]; then
    print_status 1 "Not directly logged in. XDG_SESSION_TYPE is not set."
    echo "Action needed: Install systemd-container and use machinectl to create a proper user session."
    echo "Run the following commands:"
    echo "  sudo apt-get install -y systemd-container"
    echo "  sudo machinectl shell $USER@"
    exit 1
else
    print_status 0 "Directly logged in with session type: $XDG_SESSION_TYPE."
fi

# Check if systemd-container is installed
if ! dpkg -l | grep -q systemd-container; then
    echo "Installing systemd-container..."
    sudo apt-get install -y systemd-container
    print_status $? "systemd-container installed."
else
    print_status 0 "systemd-container is already installed."
fi

# Additional test: Check if systemd user services work
echo "Testing systemd user service functionality..."
if ! systemctl --user status >/dev/null 2>&1; then
    print_status 1 "systemctl --user doesn't work properly."
    echo "This indicates you're not in a proper user session."
    echo "Action needed: Use sudo machinectl shell $USER@"
    exit 1
else
    print_status 0 "systemctl --user is working properly."
fi

echo "All tests PASSED. Your environment is suitable for Docker rootless mode."

# Check if the system-wide Docker service exists before disabling it
echo "Checking if system-wide Docker service exists..."
if systemctl list-units --type=service | grep -q docker.service; then
    sudo systemctl disable --now docker.service docker.socket
    sudo rm -f /var/run/docker.sock
    print_status $? "System-wide Docker service disabled."
else
    print_status 0 "System-wide Docker service does not exist. Skipping disable step."
fi

# Check if the rootless Docker service exists before stopping it
echo "Checking if rootless Docker service exists..."
if [ -f ~/.config/systemd/user/docker.service ]; then
    systemctl --user stop docker
    print_status $? "Rootless Docker service stopped."
    rm -f /home/$USER/bin/dockerd
    print_status $? "Rootless Docker binary removed."
else
    print_status 0 "Rootless Docker service does not exist. Skipping stop and removal steps."
fi

# Ensure the rootless Docker setup tool is installed
echo "Checking if dockerd-rootless-setuptool.sh is available..."
if ! command -v dockerd-rootless-setuptool.sh >/dev/null 2>&1; then
    print_status 1 "dockerd-rootless-setuptool.sh is not available."
    echo "Attempting to install docker-ce-rootless-extras..."
    sudo apt-get install -y docker-ce-rootless-extras
    print_status $? "docker-ce-rootless-extras installed."
fi

# Check if dockerd-rootless.sh exists
echo "Checking if dockerd-rootless.sh exists..."
if [ -f /usr/bin/dockerd-rootless.sh ]; then
    print_status 0 "dockerd-rootless.sh exists."
else
    print_status 1 "dockerd-rootless.sh does not exist. Attempting to reinstall docker-ce-rootless-extras..."
    sudo apt-get install --reinstall -y docker-ce-rootless-extras
    if [ -f /usr/bin/dockerd-rootless.sh ]; then
        print_status 0 "dockerd-rootless.sh successfully reinstalled."
    else
        print_status 1 "Failed to reinstall dockerd-rootless.sh. Exiting."
        exit 1
    fi
fi

# Check for required dependencies
echo "Checking for required dependencies..."
dependencies=("slirp4netns" "fuse-overlayfs" "uidmap")
for dep in "${dependencies[@]}"; do
    if dpkg -l | grep -q "$dep"; then
        print_status 0 "$dep is installed."
    else
        print_status 1 "$dep is not installed. Installing..."
        sudo apt-get install -y "$dep"
        if dpkg -l | grep -q "$dep"; then
            print_status 0 "$dep successfully installed."
        else
            print_status 1 "Failed to install $dep. Exiting."
            exit 1
        fi
    fi
done

# Check /proc access
echo "Checking /proc access..."
if [ ! -d /proc ]; then
    print_status 1 "/proc is not accessible. Attempting to remount..."
    sudo mount -t proc proc /proc
    if [ $? -eq 0 ]; then
        print_status 0 "/proc successfully remounted."
    else
        print_status 1 "Failed to remount /proc. Please check your system configuration."
        exit 1
    fi
else
    print_status 0 "/proc is accessible."
fi

# Check kernel support for user namespaces
echo "Checking kernel support for user namespaces..."
if [ -f /proc/config.gz ]; then
    if zgrep -q CONFIG_USER_NS /proc/config.gz; then
        print_status 0 "Kernel supports user namespaces."
    else
        print_status 1 "Kernel does not support user namespaces. Please enable CONFIG_USER_NS in your kernel configuration."
        exit 1
    fi
elif [ -f /boot/config-$(uname -r) ]; then
    if grep -q CONFIG_USER_NS /boot/config-$(uname -r); then
        print_status 0 "Kernel supports user namespaces."
    else
        print_status 1 "Kernel does not support user namespaces. Please enable CONFIG_USER_NS in your kernel configuration."
        exit 1
    fi
else
    print_status 1 "Kernel configuration file not found. Unable to verify user namespace support."
    exit 1
fi

# Test newuidmap and newgidmap
echo "Testing newuidmap and newgidmap..."
if ! newuidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
    print_status 1 "newuidmap test failed. Attempting to fix /etc/subuid configuration..."
    
    # Fix /etc/subuid
    if ! grep -q "^$USER:" /etc/subuid; then
        echo "$USER:100000:65536" | sudo tee -a /etc/subuid
        print_status $? "/etc/subuid configured for $USER."
    else
        CURRENT_SUBUID=$(grep "^$USER:" /etc/subuid | awk -F: '{print $2":"$3}')
        if [ "$CURRENT_SUBUID" != "100000:65536" ]; then
            echo "$USER:100000:65536" | sudo tee /etc/subuid
            print_status $? "/etc/subuid updated for $USER."
        else
            print_status 0 "/etc/subuid is already correctly configured for $USER."
        fi
    fi

    # Fix /etc/subgid
    if ! grep -q "^$USER:" /etc/subgid; then
        echo "$USER:100000:65536" | sudo tee -a /etc/subgid
        print_status $? "/etc/subgid configured for $USER."
    else
        CURRENT_SUBGID=$(grep "^$USER:" /etc/subgid | awk -F: '{print $2":"$3}')
        if [ "$CURRENT_SUBGID" != "100000:65536" ]; then
            echo "$USER:100000:65536" | sudo tee /etc/subgid
            print_status $? "/etc/subgid updated for $USER."
        else
            print_status 0 "/etc/subgid is already correctly configured for $USER."
        fi
    fi

    # Ensure permissions for newuidmap and newgidmap
    echo "Checking permissions for newuidmap and newgidmap..."
    sudo chmod u+s /usr/bin/newuidmap /usr/bin/newgidmap
    print_status $? "Permissions for newuidmap and newgidmap are correctly set."

    # Retry newuidmap test with debugging
    echo "Retrying newuidmap test with debugging..."
    if ! newuidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
        print_status 1 "newuidmap test failed after fixing. Collecting debugging information..."
        echo "=== Debugging Information ==="
        echo "Contents of /etc/subuid:"
        cat /etc/subuid
        echo "Contents of /etc/subgid:"
        cat /etc/subgid
        echo "Permissions of newuidmap and newgidmap:"
        ls -l /usr/bin/newuidmap /usr/bin/newgidmap
        echo "Kernel user namespace support:"
        zgrep CONFIG_USER_NS /proc/config.gz || echo "Kernel config not available."
        echo "=============================="
        exit 1
    else
        print_status 0 "newuidmap test passed after fixing."
    fi
else
    print_status 0 "newuidmap test passed."
fi

if ! newgidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
    print_status 1 "newgidmap test failed. Attempting to fix /etc/subgid configuration..."
    
    # Retry newgidmap test
    echo "Retrying newgidmap test..."
    if ! newgidmap 1000 0 1000 1 1 100000 65536 >/dev/null 2>&1; then
        print_status 1 "newgidmap test failed after fixing. Please manually check /etc/subgid and permissions."
        exit 1
    else
        print_status 0 "newgidmap test passed after fixing."
    fi
else
    print_status 0 "newgidmap test passed."
fi

# Retry rootless Docker installation
echo "Ensuring rootless Docker service is installed..."
if [ ! -f ~/.config/systemd/user/docker.service ]; then
    dockerd-rootless-setuptool.sh install || {
        print_status 1 "Failed to install rootless Docker service. Uninstalling current setup and retrying..."
        echo "Uninstalling current rootless Docker setup..."
        /usr/bin/dockerd-rootless-setuptool.sh uninstall -f
        /usr/bin/rootlesskit rm -rf ~/.local/share/docker
        print_status $? "Uninstallation completed. Retrying installation..."
        dockerd-rootless-setuptool.sh install || {
            print_status 1 "Retry failed. Exiting."
            exit 1
        }
    }
    print_status $? "Rootless Docker service installed."
else
    print_status 0 "Rootless Docker service already installed."
fi

# Start the rootless Docker service
echo "Starting the rootless Docker service..."

# Verify docker.service configuration
echo "Verifying docker.service configuration..."
if ! grep -q "/usr/bin/dockerd-rootless.sh" ~/.config/systemd/user/docker.service; then
    print_status 1 "docker.service is misconfigured. Fixing the ExecStart path..."
    sed -i 's|ExecStart=.*|ExecStart=/usr/bin/dockerd-rootless.sh|' ~/.config/systemd/user/docker.service
    systemctl --user daemon-reload
    print_status $? "docker.service configuration updated."
else
    print_status 0 "docker.service is correctly configured."
fi

# Check dependencies for dockerd-rootless.sh
echo "Checking dependencies for dockerd-rootless.sh..."
dependencies=("slirp4netns" "fuse-overlayfs" "uidmap")
for dep in "${dependencies[@]}"; do
    if ! dpkg -l | grep -q "$dep"; then
        print_status 1 "$dep is missing. Installing..."
        sudo apt-get install -y "$dep"
        print_status $? "$dep installed."
    else
        print_status 0 "$dep is already installed."
    fi
done

# Start the service
systemctl --user daemon-reload
if ! systemctl --user start docker; then
    print_status 1 "Failed to start rootless Docker service. Collecting logs..."
    echo "=== Docker Service Logs ==="
    journalctl --user -xeu docker.service | tail -n 20
    echo "==========================="
    echo "Retrying to start the service..."
    systemctl --user restart docker || {
        print_status 1 "Retry failed. Check logs with: journalctl --user -xeu docker.service"
        exit 1
    }
fi
print_status $? "Rootless Docker service started successfully."

# Enable the service to start on boot
sudo loginctl enable-linger $(whoami)
print_status $? "Linger enabled for the current user."

# Post-Installation Steps
# Set the required environment variables
export PATH=/home/$USER/bin:$PATH
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock

echo -e "\e[32mRootless Docker installation and configuration completed successfully!\e[0m"