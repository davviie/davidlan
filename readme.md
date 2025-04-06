## Add to docker
# Casa OS
curl -fsSL https://get.casaos.io | sudo bash

# Paperless
bash -c "$(curl --location --silent --show-error https://raw.githubusercontent.com/paperless-ngx/paperless-ngx/main/install-paperless-ngx.sh)"


# Actual Accounting

docker run -d \
  --name actual-budget \
  -p 5006:5006 \
  -v actual-data:/app/data \
  actualbudget/actual-server:latest
  
# Grocy


## Add CasaOS to docker
