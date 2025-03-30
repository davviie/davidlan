#!/bin/bash

# List of repositories to sync (SSH URLs only)
REPOS=(
  "git@github.com:davviie/davidlan.git"
  "git@github.com:davviie/ubuntu-server.git"
)

# Directory where repositories will be cloned/pulled
TARGET_DIR="${1:-$HOME/projects}"

# Emoji for status
CLONE="⬇️"
CLONE_SUCCESS="⬇️✅"
CLONE_FAILURE="⬇️❌"
PULL="🔄"
PULL_SUCCESS="🔄✅"
PULL_FAILURE="🔄❌"

# Ensure target directory exists
mkdir -p "$TARGET_DIR"

# Log file
LOG_FILE="$TARGET_DIR/sync.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Ensure SSH agent is running
ensure_ssh_agent() {
  local retries=3
  while ! pgrep -u "$USER" ssh-agent >/dev/null 2>&1; do
    if (( retries == 0 )); then
      echo "❌ Failed to start SSH agent after multiple attempts. Exiting."
      exit 1
    fi
    echo "🔑 SSH agent is not running. Attempting to start it..."
    eval "$(ssh-agent -s)" || {
      echo "❌ Failed to start SSH agent automatically."
      echo "Please start the SSH agent manually (e.g., by running 'eval \$(ssh-agent -s)') and press Enter to retry."
      read -p "Press Enter to retry starting the SSH agent or Ctrl+C to exit..."
    }
    ((retries--))
  done
}

# Ensure SSH key is added, or generate one if it doesn't exist
ensure_ssh_key() {
  local retries=3
  while ! ssh-add -l >/dev/null 2>&1; do
    if (( retries == 0 )); then
      echo "❌ Failed to add SSH key after multiple attempts. Exiting."
      exit 1
    fi
    echo "🔑 No SSH key found. Checking for existing keys..."
    if [ ! -f "$HOME/.ssh/id_rsa" ]; then
      echo "🔑 No SSH key found. Generating a new SSH key..."
      ssh-keygen -t rsa -b 4096 -C "your_email@example.com" -f "$HOME/.ssh/id_rsa" -N "" || {
        echo "❌ Failed to generate SSH key."
        exit 1
      }
      echo "🔑 New SSH key generated."
    fi

    echo "🔑 Adding SSH key to the agent..."
    if ! ssh-add "$HOME/.ssh/id_rsa"; then
      echo "❌ Failed to add SSH key to the agent."
      echo "Please ensure the SSH agent is running and try again."
      echo "You can manually add the key by running: ssh-add ~/.ssh/id_rsa"
      read -p "Press Enter to retry adding the SSH key or Ctrl+C to exit..."
    fi
    ((retries--))
  done

  echo "🔑 Copying SSH key to clipboard. Please add it to your GitHub account."
  cat "$HOME/.ssh/id_rsa.pub"
  echo "🔑 Visit https://github.com/settings/keys to add the SSH key."
  read -p "Press Enter after adding the SSH key to GitHub..."
}

# Test SSH connection to GitHub
test_ssh_connection() {
  echo "🔑 Testing SSH connection to GitHub..."
  if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "❌ SSH connection to GitHub failed. Please ensure your SSH key is added to GitHub."
    echo "Run the following command to test manually: ssh -T git@github.com"
    read -p "Press Enter to retry testing the SSH connection or Ctrl+C to exit..."
    test_ssh_connection
  fi
  echo "🔑 SSH connection to GitHub is working."
}

# Ensure SSH agent and key are configured
ensure_ssh_agent
ensure_ssh_key
test_ssh_connection

# Function to clone or pull a repository
sync_repo() {
  local repo_url=$1
  local repo_name=$(basename "$repo_url" .git)
  local repo_dir="$TARGET_DIR/$repo_name"

  # Check if the directory already exists
  if [ -d "$repo_dir" ]; then
    echo "$PULL Pull latest changes for '$repo_name'"
    cd "$repo_dir" || { echo "$PULL_FAILURE Failed to enter directory '$repo_dir'"; return; }
    if git pull; then
      echo "$PULL_SUCCESS Successfully pulled latest changes for '$repo_name'"
    else
      echo "$PULL_FAILURE Failed to pull latest changes for '$repo_name'"
      echo "Check for merge conflicts in '$repo_dir'"
    fi
  else
    echo "$CLONE Cloning '$repo_name' Repository"
    if git clone "$repo_url" "$repo_dir"; then
      echo "$CLONE_SUCCESS Successfully cloned '$repo_name'"
    else
      echo "$CLONE_FAILURE Failed to clone '$repo_name'"
    fi
  fi
}

# Sync each repository sequentially (interactive mode)
for repo in "${REPOS[@]}"; do
  sync_repo "$repo"
done
