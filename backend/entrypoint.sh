#!/bin/sh
# Runs inside the backend container before the app starts.
set -e

echo "Applying database migrations..."
python manage.py migrate --noinput

echo "Collecting static files..."
python manage.py collectstatic --noinput

# Hand over to the CMD (gunicorn in production, runserver in dev).
exec "$@"
