#!/bin/bash

# Set the working directory
REPO_DIR="/davviie/ubuntu-server"
BRANCH="main"
REMOTE="origin"

# Navigate to the repo directory
cd "$REPO_DIR" || { echo "Repository not found!"; exit 1; }

# Ensure the repository is clean
git reset --hard
git clean -fd

# Fetch latest changes from remote
git fetch $REMOTE $BRANCH

# Get last commit timestamps
LOCAL_TIME=$(git log -1 --format=%ct $BRANCH 2>/dev/null || echo 0)
REMOTE_TIME=$(git log -1 --format=%ct $REMOTE/$BRANCH 2>/dev/null || echo 0)

if [ "$REMOTE_TIME" -gt "$LOCAL_TIME" ]; then
    echo "Remote repository is newer. Pulling changes..."
    git pull $REMOTE $BRANCH
elif [ "$LOCAL_TIME" -gt "$REMOTE_TIME" ]; then
    echo "Local repository is newer. Pushing changes..."
    git add .
    git commit -m "Auto-sync: $(date)"
    git push $REMOTE $BRANCH
else
    echo "Repositories are already in sync."
fi
