import pytest
from rest_framework.test import APIClient

from notes.models import Note


@pytest.fixture
def api():
    return APIClient()


@pytest.mark.django_db
def test_create_note(api):
    response = api.post("/api/notes/", {"title": "Deployed v1.0", "body": "All green"}, format="json")

    assert response.status_code == 201
    assert Note.objects.count() == 1
    assert response.json()["title"] == "Deployed v1.0"


@pytest.mark.django_db
def test_blank_title_is_rejected(api):
    response = api.post("/api/notes/", {"title": "   "}, format="json")

    assert response.status_code == 400
    assert "title" in response.json()


@pytest.mark.django_db
def test_pinned_notes_come_first(api):
    Note.objects.create(title="Older pinned", pinned=True)
    Note.objects.create(title="Newer normal")

    results = api.get("/api/notes/").json()["results"]

    assert [n["title"] for n in results] == ["Older pinned", "Newer normal"]


@pytest.mark.django_db
def test_update_and_delete_note(api):
    note = Note.objects.create(title="Draft")

    patch = api.patch(f"/api/notes/{note.id}/", {"pinned": True}, format="json")
    assert patch.status_code == 200
    assert patch.json()["pinned"] is True

    delete = api.delete(f"/api/notes/{note.id}/")
    assert delete.status_code == 204
    assert not Note.objects.exists()
