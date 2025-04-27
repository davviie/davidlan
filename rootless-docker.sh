#!/bin/bash

# Install dbus-user-session package if not installed and relogin
sudo apt-get install -y dbus-user-session

# Install uidmap package if not installed
sudo apt-get install -y uidmap

# Test if user is directly logged in or needs machinectl
echo "Testing login session type..."

# Check if XDG_SESSION_TYPE exists and is not empty
if [ -z "$XDG_SESSION_TYPE" ]; then
  echo "FAIL: Not directly logged in. XDG_SESSION_TYPE is not set."
  echo "Action needed: Install systemd-container and use machinectl"

  # Check if systemd-container is installed
  if ! dpkg -l | grep -q systemd-container; then
    echo "FAIL: systemd-container is not installed"
    echo "Action needed: sudo apt-get install -y systemd-container"
  else
    echo "PASS: systemd-container is installed"
  fi

  echo "After installing systemd-container, use: sudo machinectl shell $USER@"
  exit 1
else
  echo "PASS: Directly logged in with session type: $XDG_SESSION_TYPE"
fi

# Additional test: Check if systemd user services work
echo "Testing systemd user service functionality..."
if ! systemctl --user status >/dev/null 2>&1; then
  echo "FAIL: systemctl --user doesn't work properly"
  echo "This indicates you're not in a proper user session"
  echo "Action needed: Use sudo machinectl shell $USER@"
  exit 1
else
  echo "PASS: systemctl --user is working properly"
fi

echo "All tests PASSED. Your environment is suitable for Docker rootless mode."

# Create and install the currently logged-in user's AppArmor profile
filename=$(echo $HOME/bin/rootlesskit | sed -e s@^/@@ -e s@/@.@g)
cat <<EOF > ~/${filename}
abi <abi/4.0>,
include <tunables/global>

"$HOME/bin/rootlesskit" flags=(unconfined) {
  userns,

  include if exists <local/${filename}>
}
EOF
sudo mv ~/${filename} /etc/apparmor.d/${filename}

# Restart AppArmor
systemctl restart apparmor.service

# If the system-wide Docker daemon is already running, consider disabling it
sudo systemctl disable --now docker.service docker.socket
s rm /var/run/docker.sock

# Install rootless Docker with convenience script
# This will install the latest version of Docker in rootless mode
curl -fsSL https://get.docker.com/rootless | sh

# Post-Installation Steps
# Set the required environment variables
export PATH=/home/username/bin:$PATH  # Or /usr/bin:$PATH if using packages
export DOCKER_HOST=unix:///run/user/1000/docker.sock

# Enable the service to start on boot
sudo loginctl enable-linger $(whoami)

# Start the service
systemctl --user start docker