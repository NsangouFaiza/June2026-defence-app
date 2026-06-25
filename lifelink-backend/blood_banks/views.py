from rest_framework import viewsets, permissions
from .models import BloodBank
from .serializers import BloodBankSerializer


class BloodBankViewSet(viewsets.ModelViewSet):
    """ViewSet for BloodBank model."""

    queryset = BloodBank.objects.all()
    serializer_class = BloodBankSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['region', 'city', 'is_active']
    search_fields = ['name', 'address', 'city', 'region']

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]
