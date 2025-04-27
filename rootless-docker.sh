# Remove any old Docker installations
echo "Removing old Docker installations (if any)..."
sudo apt-get remove -y docker docker-engine docker.io containerd runc

# Update package lists
echo "Updating package lists..."
sudo apt-get update

# Install required packages for Docker installation
echo "Installing required packages for Docker repository setup..."
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg \
    lsb-release

# Add Docker's official GPG key
echo "Adding Docker's official GPG key..."
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up the Docker stable repository
echo "Setting up the Docker stable repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package lists again to include Docker's repository
echo "Updating package lists to include Docker's repository..."
sudo apt-get update

# Install Docker Engine and related components
echo "Installing Docker Engine and related components..."
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable the Docker service
echo "Starting and enabling the Docker service..."
sudo systemctl start docker
sudo systemctl enable docker

# Test Docker installation as root
echo "Testing Docker installation with 'hello-world' container (as root)..."
sudo docker run hello-world

# Prompt for post-installation steps
echo "Post-installation steps for Docker:"
echo "To run Docker as a non-root user, you need to add your user to the 'docker' group."

# Add the current user to the 'docker' group
echo "Adding the current user ($USER) to the 'docker' group..."
sudo usermod -aG docker $USER

# Check if the user is already part of the 'docker' group
if groups $USER | grep -q "\bdocker\b"; then
    echo "You are already part of the 'docker' group. No need to log out."
    echo "You can now run Docker commands without 'sudo'."
else
    echo "You have been added to the 'docker' group. Applying group changes with 'newgrp docker'..."
    echo "Starting a new shell session for the 'docker' group..."
    newgrp docker
    echo "Testing Docker as a non-root user..."
    docker run hello-world
    exit 0
fi

# Check Docker installation and AppArmor status
echo "Verifying Docker installation and AppArmor status..."
sudo aa-status
systemctl status docker --no-pager

# Prompt the user to log out and log back in
echo "Step 2: Log Out and Log Back In"
echo "Log out of your current session and log back in to apply the group changes."
echo "You will be logged out automatically in 20 seconds."
echo "Press Enter to log out now, or press 'c' to cancel."

# Wait for user input or timeout
read -t 20 -n 1 user_input

if [[ "$user_input" == "c" || "$user_input" == "C" ]]; then
    echo "Logout canceled. Please remember to log out and log back in manually to apply the changes."
    exit 0
else
    echo "Logging out..."
    # Log out the user
    gnome-session-quit --logout --no-prompt || pkill -KILL -u "$USER"
fi

