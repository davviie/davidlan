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

# Fetch the latest changes from the remote repository
git fetch origin main

# Reset the current directory to match the remote repository's main branch
git reset --hard origin/main

# Check out the main branch
git checkout -b main --track origin/main

# Pull the latest changes to ensure you're up-to-date
git pull origin main

# Make your changes and add them to staging
git add .

# Commit your changes with a message
git commit -m "Your commit message here"

# Push your changes to the remote repository
git push origin main

```

## Add to docker
# Casa OS
```bash
curl -fsSL https://get.casaos.io | sudo bash
```

# Paperless
```bash
bash -c "$(curl --location --silent --show-error https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/install-paperless-ngx.sh)"
```

# Actual Accounting
```bash
docker run -d \
  --name actual-budget \
  -p 5006:5006 \
  -v actual-data:/app/data \
  actualbudget/actual-server:latest
```
# Grocy


## Add CasaOS to docker
