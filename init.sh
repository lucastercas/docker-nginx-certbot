#!/bin/bash

project_name=$1
domain="$2"
email="lucasmtercas@gmail.com"
etc_volume_name="${project_name}_certbot-etc"
etc_volume_path="/var/lib/docker/volumes/$etc_volume_name/_data"

docker-compose up -d
docker-compose down

echo "#===== Getting Recommended TLS Parameters =====#"
sudo curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf > "$etc_volume_path/options-ssl-nginx.conf"
sudo curl -s https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem > "$etc_volume_path/ssl-dhparams.pem"

echo "#===== Creating Dummy Certificates =====#"
sudo mkdir -p "$etc_volume_path/live/$domain"
path="/etc/letsencrypt/live/$domain"
docker-compose run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:1024 -days 1\
    -keyout '$path/privkey.pem' \
    -out '$path/fullchain.pem' \
    -subj '/CN=localhost'" certbot
echo

echo "#===== Restarting NGINX =====#"
docker-compose up --force-recreate -d nginx
echo

echo "#===== Removing Dummy Certificates =====#"
docker-compose run --rm --entrypoint "rm -Rf /etc/letsencrypt/live/$domain && rm -Rf /etc/letsencrypt/archive/$domain && rm -Rf /etc/letsencrypt/renewal/$domain.conf" certbot
echo

echo "#===== Creating Production Certificates =====#"
docker-compose run --rm --entrypoint "certbot certonly --webroot --webroot-path=/data/letsencrypt --email $email --agree-tos --no-eff-email -d $domain" certbot
echo

echo "#===== Reloading NGINX =====#"
docker-compose exec nginx nginx -s reload
echo
