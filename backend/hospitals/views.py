from django.db.models import Count, Sum, Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta

from .models import Hospital, HospitalStaff
from .serializers import HospitalSerializer, HospitalStaffSerializer


class HospitalViewSet(viewsets.ModelViewSet):
    """ViewSet for Hospital model."""

    queryset = Hospital.objects.all()
    serializer_class = HospitalSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['region', 'city', 'is_active']
    search_fields = ['name', 'address', 'city', 'region']

    def get_permissions(self):
        if self.action in ['list', 'retrieve']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    @action(detail=False, methods=['get'])
    def my_hospital(self, request):
        """Get the hospital associated with the current user."""
        try:
            staff = HospitalStaff.objects.get(user=request.user)
            serializer = HospitalSerializer(staff.hospital)
            return Response(serializer.data)
        except HospitalStaff.DoesNotExist:
            return Response(
                {'detail': 'No hospital assigned to this user.'},
                status=status.HTTP_404_NOT_FOUND
            )

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """Get hospital statistics."""
        try:
            staff = HospitalStaff.objects.get(user=request.user)
            hospital = staff.hospital
        except HospitalStaff.DoesNotExist:
            return Response(
                {'detail': 'No hospital assigned to this user.'},
                status=status.HTTP_404_NOT_FOUND
            )

        from ..inventory.models import BloodInventory
        from ..appointments.models import Appointment
        from ..requests.models import BloodRequest

        total_units = BloodInventory.objects.filter(hospital=hospital).aggregate(
            total=Sum('quantity')
        )['total'] or 0

        low_stock = BloodInventory.objects.filter(
            hospital=hospital, quantity__lt=5
        ).count()

        pending_appointments = Appointment.objects.filter(
            hospital=hospital, status='SCHEDULED'
        ).count()

        active_requests = BloodRequest.objects.filter(
            hospital=hospital, status='PENDING'
        ).count()

        return Response({
            'total_blood_units': total_units,
            'low_stock_alerts': low_stock,
            'pending_appointments': pending_appointments,
            'active_requests': active_requests,
        })


class HospitalStaffViewSet(viewsets.ModelViewSet):
    """ViewSet for HospitalStaff model."""

    queryset = HospitalStaff.objects.all()
    serializer_class = HospitalStaffSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['hospital', 'is_active']
