#!/bin/bash

# Synchronize the current Git repository with the remote one
echo "🔄 Fetching changes from the remote repository..."
git fetch origin

echo "🔄 Merging changes from the remote repository..."
git merge origin/main

echo "🔄 Rebasing local changes onto the remote branch..."
git rebase origin/main

echo "🔄 Pulling the latest changes from the remote repository..."
git pull origin main

echo "🔄 Adding and committing local changes..."
git add .
git commit -m "Synchronized changes" || echo "No changes to commit."

echo "🔄 Pushing changes to the remote repository..."
git push origin main

echo "✅ Synchronization complete!"
