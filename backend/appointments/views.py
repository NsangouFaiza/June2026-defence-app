from django.db.models import Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone

from .models import Appointment
from .serializers import AppointmentSerializer


class AppointmentViewSet(viewsets.ModelViewSet):
    """ViewSet for Appointment model."""

    queryset = Appointment.objects.all()
    serializer_class = AppointmentSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['donor', 'hospital', 'status', 'scheduled_date']
    search_fields = ['donor__user__first_name', 'donor__user__last_name', 'hospital__name']

    def create(self, request, *args, **kwargs):
        print("APPOINTMENT CREATE REQUEST DATA:", request.data, flush=True)
        serializer = self.get_serializer(data=request.data)
        if not serializer.is_valid():
            print("APPOINTMENT SERIALIZER ERRORS:", serializer.errors, flush=True)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
        self.perform_create(serializer)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    def perform_create(self, serializer):
        from donors.models import Donor
        is_staff = self.request.user.is_staff or self.request.user.role in ('hospital_staff', 'blood_bank_admin', 'system_admin', 'lab_technician')
        donor_id = self.request.data.get('donor')
        
        if is_staff and donor_id:
            try:
                donor = Donor.objects.get(pk=donor_id)
            except Donor.DoesNotExist:
                donor, created = Donor.objects.get_or_create(user=self.request.user)
        else:
            donor, created = Donor.objects.get_or_create(user=self.request.user)
            
        serializer.save(donor=donor)

    @action(detail=False, methods=['get'])
    def my_appointments(self, request):
        """Get current user's appointments."""
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
            queryset = Appointment.objects.filter(donor=donor)
            serializer = self.get_serializer(queryset, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response([])

    @action(detail=False, methods=['get'])
    def upcoming(self, request):
        """Get upcoming appointments."""
        queryset = Appointment.objects.filter(
            scheduled_date__gte=timezone.now().date(),
            status='SCHEDULED',
        ).order_by('scheduled_date', 'scheduled_time')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], url_path='available-slots')
    def available_slots(self, request):
        """Get available time slots for a hospital on a given date."""
        hospital_id = request.query_params.get('hospital')
        date_str = request.query_params.get('date')

        if not hospital_id or not date_str:
            return Response(
                {'error': 'hospital and date parameters are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from datetime import datetime
        try:
            target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
        except ValueError:
            return Response(
                {'error': 'Invalid date format. Use YYYY-MM-DD'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        existing = Appointment.objects.filter(
            hospital_id=hospital_id,
            scheduled_date=target_date,
        ).values_list('scheduled_time', flat=True)

        booked = [t.strftime('%H:%M') for t in existing]
        slots = []
        for hour in range(8, 18):
            slot = f"{hour:02d}:00"
            if slot not in booked:
                slots.append(slot)

        return Response({'date': date_str, 'hospital': hospital_id, 'available_slots': slots})

    @action(detail=True, methods=['post'])
    def confirm(self, request, pk=None):
        """Confirm appointment (hospital staff)."""
        appointment = self.get_object()
        appointment.status = 'CONFIRMED'
        appointment.save()
        serializer = self.get_serializer(appointment)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel appointment."""
        appointment = self.get_object()
        reason = request.data.get('reason', '')
        appointment.status = 'CANCELLED'
        appointment.notes = reason
        appointment.save()
        serializer = self.get_serializer(appointment)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def complete(self, request, pk=None):
        """Mark appointment as completed."""
        appointment = self.get_object()
        appointment.status = 'COMPLETED'
        appointment.save()

        # Auto-create completed donation record
        from donations.models import Donation
        donation, created = Donation.objects.get_or_create(
            appointment=appointment,
            defaults={
                'donor': appointment.donor,
                'hospital': appointment.hospital,
                'blood_group': appointment.donor.user.blood_group or 'O+',
                'quantity_ml': 450,
                'status': 'COMPLETED',
                'screened_by': request.user,
                'is_usable': True,
            }
        )
        if not created and donation.status != 'COMPLETED':
            donation.status = 'COMPLETED'
            donation.save()

        serializer = self.get_serializer(appointment)
        return Response(serializer.data)
