#!/usr/bin/env bash
# Called by GitHub Actions over SSH on every release:
#   TAG=<git sha> ./scripts/deploy.sh
#
# Pulls the new images, restarts the stack with zero manual steps, and
# cleans up old images so the disk does not fill up.
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${TAG:?TAG (image tag) is required}"
COMPOSE="docker compose -f docker-compose.prod.yml"

# Record the release in .env so a manual `docker compose up` uses the same tag.
if grep -q '^TAG=' .env; then
  sed -i "s/^TAG=.*/TAG=${TAG}/" .env
else
  echo "TAG=${TAG}" >> .env
fi
export TAG

echo "==> Pulling images for tag ${TAG}"
$COMPOSE pull backend nginx

echo "==> Starting containers"
# The backend entrypoint runs migrations and collectstatic before gunicorn.
$COMPOSE up -d --remove-orphans

echo "==> Removing unused images"
docker image prune -f

$COMPOSE ps
