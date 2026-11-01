"""
Pick the settings module from the DJANGO_ENV environment variable.

    DJANGO_ENV=development  -> config/settings/development.py (default)
    DJANGO_ENV=staging      -> config/settings/staging.py
    DJANGO_ENV=production   -> config/settings/production.py

This keeps one DJANGO_SETTINGS_MODULE ("config.settings") everywhere and lets
each server choose its behaviour with a single environment variable.
"""

import os

DJANGO_ENV = os.environ.get("DJANGO_ENV", "development").lower()

if DJANGO_ENV == "production":
    from .production import *  # noqa: F401,F403
elif DJANGO_ENV == "staging":
    from .staging import *  # noqa: F401,F403
else:
    from .development import *  # noqa: F401,F403
