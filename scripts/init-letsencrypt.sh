#!/usr/bin/env bash
# Get the first Let's Encrypt certificate for $DOMAIN.
#
# Nginx will not start without a certificate, and certbot needs Nginx running
# to answer the HTTP challenge. So we:
#   1. create a temporary self-signed certificate,
#   2. start Nginx,
#   3. delete the dummy cert and request the real one through Nginx,
#   4. reload Nginx.
#
# Usage (on the server):  cd /opt/app && ./scripts/init-letsencrypt.sh
# Set STAGING=1 to use Let's Encrypt's test CA while trying things out.
set -euo pipefail

cd "$(dirname "$0")/.."
# Export every variable from .env.
set -a
# shellcheck disable=SC1091
source .env
set +a

: "${DOMAIN:?DOMAIN must be set in .env}"
: "${LETSENCRYPT_EMAIL:?LETSENCRYPT_EMAIL must be set in .env}"

COMPOSE="docker compose -f docker-compose.prod.yml"
CERT_PATH="/etc/letsencrypt/live/$DOMAIN"

mkdir -p certbot/conf certbot/www

echo "==> Creating a temporary certificate for $DOMAIN"
mkdir -p "certbot/conf/live/$DOMAIN"
$COMPOSE run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout '$CERT_PATH/privkey.pem' \
    -out '$CERT_PATH/fullchain.pem' \
    -subj '/CN=localhost'" certbot

echo "==> Starting Nginx"
$COMPOSE up -d nginx

echo "==> Removing the temporary certificate"
$COMPOSE run --rm --entrypoint "\
  rm -rf /etc/letsencrypt/live/$DOMAIN /etc/letsencrypt/archive/$DOMAIN \
         /etc/letsencrypt/renewal/$DOMAIN.conf" certbot

STAGING_ARG=""
if [ "${STAGING:-0}" != "0" ]; then STAGING_ARG="--staging"; fi

echo "==> Requesting the real certificate from Let's Encrypt"
$COMPOSE run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot $STAGING_ARG \
    --email $LETSENCRYPT_EMAIL --agree-tos --no-eff-email \
    -d $DOMAIN" certbot

echo "==> Reloading Nginx with the new certificate"
$COMPOSE exec nginx nginx -s reload

echo "HTTPS is ready: https://$DOMAIN"
