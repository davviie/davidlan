#!/bin/bash

# Step 1: Uninstall Docker and Remove Services/Sockets
echo "Uninstalling Docker and removing related services and sockets..."
sudo systemctl stop docker.service docker.socket
sudo systemctl disable docker.service docker.socket
sudo rm -f /lib/systemd/system/docker.service /lib/systemd/system/docker.socket
sudo rm -rf /run/docker.sock
sudo apt-get remove -y docker docker-engine docker.io containerd runc docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
sudo apt-get autoremove -y
echo "Docker has been uninstalled, and related services and sockets have been removed."

# Step 2: Install Docker
echo "Installing Docker..."
sudo apt-get update
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

# Install Docker Engine and related components
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl start docker
sudo systemctl enable docker
echo "Docker installation completed successfully."

# Step 3: Reset Docker Socket and Permissions
echo "Resetting Docker socket and permissions..."
sudo systemctl stop docker.service docker.socket
sudo rm -rf /run/docker.sock
sudo systemctl start docker.service
echo "Docker socket has been reset."

# Step 4: Verify Docker Group and GID
echo "Verifying Docker group and user permissions..."
if ! getent group docker > /dev/null; then
    echo "Docker group does not exist. Creating it..."
    sudo groupadd docker
else
    echo "Docker group already exists."
fi

echo "Adding the current user ($USER) to the 'docker' group..."
sudo usermod -aG docker $USER
echo "You have been added to the 'docker' group. Please log out and log back in to apply the changes."

# Step 5: Generate .env File
echo "Generating .env file..."
cat <<EOF > .env
PUID=$(id -u)                  # Get the current user's UID
PGID=$(id -g)                  # Get the current user's GID
TZ=$(cat /etc/timezone 2>/dev/null || echo "Etc/UTC") # Get the system timezone
DOMAIN=$(hostname -f)               # Custom domain name for Traefik routing
HOSTNAME=$(hostname)           # System hostname for local network identification
DOCKER_SOCK=/var/run/docker.sock
DOCKERDATA=./dockerdata
MEDIA=./media
TORRENTS=./torrents

# ID and Tokens
VAULTWARDEN_ADMIN_TOKEN=your_secure_admin_token
TRAEFIK_ACME_EMAIL=mail@davidlan.xyz
PLEX_CLAIM=mraYUbL2QPo7onDyhrok
PLEX_PASS=true
ADVERTISE_IP=http://$(hostname -I | awk '{print $1}'):32400 # Automatically set local IP

# Ports

PORTAINER_PORT=9000
PORTAINER_AGENT_PORT=9001
OVERSEERR_PORT=5055
SONARR_PORT=8989
RADARR_PORT=7878
PROWLARR_PORT=9696
MYLAR_PORT=8090
BAZARR_PORT=6767
LAZYLIBRARIAN_PORT=5299
LIDARR_PORT=8686
WHISPARR_PORT=6969
JELLYFIN_PORT=8096
JELLYFIN_HTTPS_PORT=8920
PLEX_PORT=32400
AUDIOBOOKSHELF_PORT=13378
STIRLINGPDF_PORT=5060
TRAEFIK_HTTP_PORT=80
TRAEFIK_HTTPS_PORT=443
TRAEFIK_DASHBOARD_PORT=8080
FILEZILLA_PORT=3010
NETDATA_PORT=19999
SPEEDTEST_PORT=8765
UPTIME_KUMA_PORT=3011
VAULTWARDEN_PORT=8093
HEIMDALL_PORT=3002
HOMEPAGE_PORT=3003
NGINX_HTTP_PORT=8088
NGINX_HTTPS_PORT=8443
EOF
echo ".env file generated successfully!"

# Step 6: Create Docker Network
echo "Creating default Docker network 'dockernet'..."
docker network create dockernet || echo "Network 'dockernet' already exists."
echo "Default Docker network 'dockernet' created successfully!"

# Step 7: Set Default Network for Docker Compose
echo "Setting 'dockernet' as the default network in Docker Compose files..."
cat <<EOF > docker-compose.override.yml
networks:
  default:
    name: dockernet
EOF
echo "Default network set to 'dockernet'."

# Final Instructions
echo "Docker setup is complete!"
echo "Please log out and log back in to apply the group changes."
echo "After logging back in, test Docker by running: docker run hello-world"

