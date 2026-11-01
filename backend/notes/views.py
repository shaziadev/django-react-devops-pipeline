from django.conf import settings
from django.db import connection
from django.db.utils import OperationalError
from rest_framework import status, viewsets
from rest_framework.decorators import api_view
from rest_framework.response import Response

from .models import Note
from .serializers import NoteSerializer


class NoteViewSet(viewsets.ModelViewSet):
    """CRUD endpoints for notes: /api/notes/ and /api/notes/<id>/."""

    queryset = Note.objects.all()
    serializer_class = NoteSerializer


@api_view(["GET"])
def health(request):
    """
    Health check used by the deploy pipeline and by Docker.

    Returns 200 when the app can reach the database, 503 otherwise, so a
    broken release is caught right after deployment.
    """
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
        database = "ok"
    except OperationalError:
        database = "unavailable"

    healthy = database == "ok"
    return Response(
        {
            "status": "ok" if healthy else "error",
            "database": database,
            "environment": settings.DJANGO_ENV,
            "version": settings.APP_VERSION,
        },
        status=status.HTTP_200_OK if healthy else status.HTTP_503_SERVICE_UNAVAILABLE,
    )
