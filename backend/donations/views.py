from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Donation
from .serializers import DonationSerializer


class DonationViewSet(viewsets.ModelViewSet):
    """ViewSet for Donation model."""

    queryset = Donation.objects.all()
    serializer_class = DonationSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['donor', 'hospital', 'status']
    search_fields = ['donor__user__first_name', 'donor__user__last_name', 'hospital__name']

    def perform_create(self, serializer):
        if self.request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            from rest_framework.exceptions import PermissionDenied
            raise PermissionDenied('Only lab technicians and administrators can record donations.')
        serializer.save(screened_by=self.request.user)

    @action(detail=False, methods=['get'])
    def my_donations(self, request):
        """Get current donor's donation history."""
        try:
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            queryset = Donation.objects.filter(donor=donor)
            serializer = self.get_serializer(queryset, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response(
                {'error': 'Donor profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=['post'])
    def mark_completed(self, request, pk=None):
        """Mark a donation as completed."""
        donation = self.get_object()
        donation.status = 'COMPLETED'
        donation.save()
        serializer = self.get_serializer(donation)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def record_screening(self, request, pk=None):
        """Lab technician records screening results."""
        if request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        donation = self.get_object()
        donation.screened_by = request.user
        donation.screening_notes = request.data.get('screening_notes', '')
        donation.is_usable = request.data.get('is_usable', True)
        donation.status = 'COMPLETED' if donation.is_usable else 'REJECTED'
        donation.save()
        serializer = self.get_serializer(donation)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def verify(self, request, pk=None):
        """Verify donation (sets is_usable to True, status to COMPLETED)."""
        if request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        donation = self.get_object()
        donation.screened_by = request.user
        donation.is_usable = True
        donation.status = 'COMPLETED'
        donation.save()
        serializer = self.get_serializer(donation)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def record_donation(self, request):
        """Lab technician records a new donation from a completed appointment."""
        if request.user.role not in ('lab_technician', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            donation = serializer.save(screened_by=request.user)
            return Response(self.get_serializer(donation).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
