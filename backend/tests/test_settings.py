import importlib

import pytest
from django.core.exceptions import ImproperlyConfigured


def test_production_requires_secret_key(monkeypatch):
    monkeypatch.delenv("DJANGO_SECRET_KEY", raising=False)

    with pytest.raises(ImproperlyConfigured):
        import config.settings.production as production

        importlib.reload(production)


def test_production_reads_hosts_from_env(monkeypatch):
    monkeypatch.setenv("DJANGO_SECRET_KEY", "test-secret")
    monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "example.com,www.example.com")
    import config.settings.production as production

    production = importlib.reload(production)

    assert production.DEBUG is False
    assert production.ALLOWED_HOSTS == ["example.com", "www.example.com"]
    assert production.SESSION_COOKIE_SECURE is True
