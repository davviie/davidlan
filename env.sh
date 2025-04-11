#!/bin/bash

# Generate .env file
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

# Create Docker network 'dockernet'
echo "Creating default Docker network 'dockernet'..."
docker network create dockernet || echo "Network 'dockernet' already exists."
echo "Default Docker network 'dockernet' created successfully!"

# Set 'dockernet' as the default network for Docker Compose
echo "Setting 'dockernet' as the default network in Docker Compose files..."
cat <<EOF > docker-compose.override.yml
networks:
  default:
    name: dockernet
EOF

echo "Default network set to 'dockernet'."