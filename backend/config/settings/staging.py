"""Staging: production-like, but with a separate host and verbose logs."""

from .production import *  # noqa: F401,F403

# Staging gets more detailed logs to help debug before a release.
LOGGING["root"]["level"] = "DEBUG"
