#!/bin/bash

# Function to handle errors and log them
log_error() {
    echo "[ERROR] $1" | tee -a docker_install_debug.log
    exit 1
}

# Function to print status with colors
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "\e[32m[PASS]\e[0m $2"
    else
        echo -e "\e[31m[FAIL]\e[0m $2"
        log_error "$2"
    fi
}

# Check if the current user is already in the "docker" group
echo "Checking if the current user is in the 'docker' group..."
if groups $USER | grep -q "\bdocker\b"; then
    print_status 0 "User is already in the 'docker' group. Continuing..."
else
    echo "Adding the current user to the 'docker' group..."
    sudo usermod -aG docker $USER || log_error "Failed to add user to the Docker group."
    print_status $? "User added to the 'docker' group successfully."
    echo -e "\e[33m[INFO]\e[0m Please log out and log back in to apply group changes."
    echo -e "\e[33m[INFO]\e[0m Use the following commands to log out and restart the script:"
    echo -e "\e[33m[INFO]\e[0m 1. Log out: \`logout\`"
    echo -e "\e[33m[INFO]\e[0m 2. Log back in and restart the script: \`./install_docker_rootless.sh\`"
    exit 0
fi

# Step 0: Stop any existing Docker services
echo "Stopping any existing Docker services..."
sudo systemctl stop docker docker.socket containerd || true
sudo systemctl disable docker docker.socket containerd || true
sudo killall dockerd || true
sudo rm -f /var/run/docker.sock || true
print_status $? "Stopped and disabled existing Docker services."

# Step 0.1: Remove any existing Docker installations
echo "Removing any existing Docker installations..."
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
sudo rm -rf /var/lib/docker /etc/docker || true
sudo rm -rf ~/.docker || true
print_status $? "Removed existing Docker installations and cleaned up configuration."

# Step 0.2: Install required dependencies for rootless Docker
echo "Installing required dependencies for rootless Docker..."
sudo apt-get install -y slirp4netns fuse-overlayfs uidmap || log_error "Failed to install required dependencies."
print_status $? "Required dependencies installed successfully."

# Update and install prerequisites
echo "Updating package database and installing prerequisites..."
sudo apt-get update || log_error "Failed to update package database."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release || log_error "Failed to install prerequisites."
print_status $? "Prerequisites installed successfully."

# Add Docker's official GPG key
echo "Adding Docker's GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg || log_error "Failed to add Docker's GPG key."
print_status $? "Docker's GPG key added successfully."

# Set up the stable Docker repository
echo "Setting up the stable Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null || log_error "Failed to set up Docker repository."
sudo apt-get update || log_error "Failed to update package database after adding Docker repository."
print_status $? "Docker repository set up successfully."

# Install Docker components
echo "Installing Docker components..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || log_error "Failed to install Docker components."
print_status $? "Docker components installed successfully."

# Install Docker rootless mode
echo "Installing Docker rootless mode..."
sudo systemctl stop docker docker.socket containerd || true
sudo rm -f /var/run/docker.sock || true
FORCE_ROOTLESS_INSTALL=1 curl -fsSL https://get.docker.com/rootless | sh || log_error "Failed to install Docker rootless mode."
print_status $? "Docker rootless mode installed successfully."

# Export DOCKER_HOST for the current session
echo "Configuring DOCKER_HOST for rootless mode..."
export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock
if ! grep -q "export DOCKER_HOST=unix://\$XDG_RUNTIME_DIR/docker.sock" ~/.bashrc; then
    echo 'export DOCKER_HOST=unix://$XDG_RUNTIME_DIR/docker.sock' >> ~/.bashrc
    echo "DOCKER_HOST variable has been added to ~/.bashrc for persistence."
fi
source ~/.bashrc || log_error "Failed to reload shell configuration."
print_status $? "DOCKER_HOST configured successfully."

# Start the rootless Docker service
echo "Starting the rootless Docker service..."
systemctl --user start docker || log_error "Failed to start rootless Docker service."
systemctl --user enable docker || log_error "Failed to enable rootless Docker service."
print_status $? "Rootless Docker service started and enabled successfully."

# Verify Docker rootless mode
echo "Verifying Docker rootless mode..."
docker info | grep "Rootless" || log_error "Docker is not running in rootless mode."
print_status $? "Docker is running in rootless mode."

# Step 1: Run 'docker info'
echo "Running 'docker info' to verify Docker is functioning..."
docker info > /dev/null 2>&1
print_status $? "'docker info' command executed successfully."

# Step 2: Run the 'hello-world' container test
echo "Running the 'hello-world' container test..."
docker run --rm hello-world > /dev/null 2>&1
print_status $? "'hello-world' container test passed."

# Final Message
echo -e "\e[32mDocker installation and validation completed successfully!\e[0m"