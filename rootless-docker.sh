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

# Ensure /etc/subuid and /etc/subgid are configured
echo "Checking /etc/subuid and /etc/subgid configuration..."
if ! grep -q "^$USER:" /etc/subuid; then
    echo "$USER:100000:65536" | sudo tee -a /etc/subuid
    print_status $? "/etc/subuid configured for $USER."
else
    print_status 0 "/etc/subuid is already configured for $USER."
fi

if ! grep -q "^$USER:" /etc/subgid; then
    echo "$USER:100000:65536" | sudo tee -a /etc/subgid
    print_status $? "/etc/subgid configured for $USER."
else
    print_status 0 "/etc/subgid is already configured for $USER."
fi

# Retry rootless Docker installation
echo "Ensuring rootless Docker service is installed..."
if [ ! -f ~/.config/systemd/user/docker.service ]; then
    dockerd-rootless-setuptool.sh install || {
        print_status 1 "Failed to install rootless Docker service. Check logs with: journalctl --user -xeu docker.service"
        echo "If the issue persists, uninstall the current setup and retry:"
        echo "  /usr/bin/dockerd-rootless-setuptool.sh uninstall -f"
        echo "  /usr/bin/rootlesskit rm -rf ~/.local/share/docker"
        exit 1
    }
    print_status $? "Rootless Docker service installed."
else
    print_status 0 "Rootless Docker service already installed."
fi

# Start the rootless Docker service
echo "Starting the rootless Docker service..."
systemctl --user daemon-reload
systemctl --user start docker || {
    print_status 1 "Failed to start rootless Docker service. Check logs with: journalctl --user -xeu docker.service"
    exit 1
}
print_status $? "Rootless Docker service started."

# Enable the service to start on boot
sudo loginctl enable-linger $(whoami)
print_status $? "Linger enabled for the current user."

# Post-Installation Steps
# Set the required environment variables
export PATH=/home/$USER/bin:$PATH
export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock

echo -e "\e[32mRootless Docker installation and configuration completed successfully!\e[0m"