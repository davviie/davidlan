##Set up the Git Repo
```bash

# Take Ownership
sudo chown -R $USER:$USER /docker

# Navigate to docker directory
cd ~/docker

# Initialize Git in the current directory
git init

git config --global --add safe.directory /docker


# Add the remote repository
git remote add origin https://github.com/davviie/davidlan.git
git remote set-url origin git@github.com:davviie/davidlan.git

# Fetch the latest changes from the remote repository
git fetch origin main

# Reset the current directory to match the remote repository's main branch
git reset --hard origin/main

# Check out the main branch
git checkout -b main --track origin/main

# Pull the latest changes to ensure you're up-to-date
git pull origin main

# Make your changes and add them to staging
ch
```

