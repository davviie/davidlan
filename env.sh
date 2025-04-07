#!/bin/bash

# Generate .env file
cat <<EOF > .env
PUID=$(id -u)                  # Get the current user's UID
PGID=$(id -g)                  # Get the current user's GID
TZ=$(cat /etc/timezone 2>/dev/null || echo "Etc/UTC") # Get the system timezone
DOMAIN=david.lan               # Set your domain name
HOSTNAME=$(hostname)           # Get the system hostname
DOCKER_SOCK=/var/run/docker.sock
DOCKERDATA=./dockerdata
MEDIA=./media
TORRENTS=./torrents

# Ports
PORTAINER_PORT=9000
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
PLEX_PORT=32400
AUDIOBOOKSHELF_PORT=13378
STIRLINGPDF_PORT=5050
TRAEFIK_HTTP_PORT=80
TRAEFIK_HTTPS_PORT=443
TRAEFIK_DASHBOARD_PORT=8080
TRAEFIK_ACME_EMAIL=mail@davidlan.xyz
CASAOS_HTTP_PORT=88
CASAOS_HTTPS_PORT=444
FILEZILLA_PORT=3000
NETDATA_PORT=19999
SPEEDTEST_PORT=8765
UPTIME_KUMA_PORT=3001
VAULTWARDEN_PORT=8083
VAULTWARDEN_ADMIN_TOKEN=your_secure_admin_token
HEIMDALL_PORT=3002
HOMEPAGE_PORT=3003
EOF

echo ".env file generated successfully!"