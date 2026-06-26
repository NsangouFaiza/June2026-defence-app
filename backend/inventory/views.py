from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db.models import Q

from .models import BloodInventory
from .serializers import BloodInventorySerializer


class IsStaffOrTechnicianOrAdmin(permissions.BasePermission):
    """Permission class to restrict inventory management to lab technicians, hospital staff, and admins."""

    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and (
            request.user.role in ('lab_technician', 'hospital_staff', 'blood_bank_admin', 'system_admin')
            or request.user.is_staff
        )


class BloodInventoryViewSet(viewsets.ModelViewSet):
    """ViewSet for BloodInventory model."""

    queryset = BloodInventory.objects.all()
    serializer_class = BloodInventorySerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['hospital', 'blood_group', 'status']
    search_fields = ['hospital__name', 'blood_group']

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'search']:
            return [permissions.AllowAny()]
        return [IsStaffOrTechnicianOrAdmin()]

    @action(detail=False, methods=['get'])
    def search(self, request):
        """Search blood inventory by filters."""
        blood_group = request.query_params.get('blood_group')
        region = request.query_params.get('region')
        hospital_id = request.query_params.get('hospital')

        queryset = BloodInventory.objects.filter(status='available')

        if blood_group:
            queryset = queryset.filter(blood_group=blood_group)
        if region:
            queryset = queryset.filter(hospital__region=region)
        if hospital_id:
            queryset = queryset.filter(hospital_id=hospital_id)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def low_stock(self, request):
        """Get low stock alerts."""
        queryset = BloodInventory.objects.filter(
            quantity__lt=5, status='available'
        ).order_by('quantity')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def expiring_soon(self, request):
        """Get inventory expiring within 30 days."""
        from django.utils import timezone
        from datetime import timedelta

        expiry_date = timezone.now().date() + timedelta(days=30)
        queryset = BloodInventory.objects.filter(
            expiration_date__lte=expiry_date,
            status='available',
        ).order_by('expiration_date')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def approve_unit(self, request, pk=None):
        """Lab technician approves a blood unit for inventory."""
        if request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        unit = self.get_object()
        unit.status = 'available'
        unit.save()
        return Response(self.get_serializer(unit).data)

    @action(detail=True, methods=['post'])
    def reject_unit(self, request, pk=None):
        """Lab technician rejects a blood unit."""
        if request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        unit = self.get_object()
        unit.status = 'rejected'
        unit.save()
        return Response(self.get_serializer(unit).data)
