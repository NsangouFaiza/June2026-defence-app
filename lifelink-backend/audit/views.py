from django.db.models import Sum, Count
from rest_framework import generics, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets
from rest_framework.views import APIView
from django.contrib.auth import get_user_model

from .models import AuditLog
from .serializers import AuditLogSerializer

User = get_user_model()


class AuditLogListView(generics.ListAPIView):
    serializer_class = AuditLogSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['user', 'action', 'model_name']

    def get_queryset(self):
        return AuditLog.objects.all()


class AdminUserViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAdminUser]

    def list(self, request):
        """List all users."""
        users = User.objects.all()
        data = []
        for u in users:
            data.append({
                'id': u.id,
                'email': u.email,
                'full_name': u.full_name,
                'role': getattr(u, 'role', ''),
                'is_active': u.is_active,
                'is_verified': getattr(u, 'is_verified', False),
                'date_joined': u.date_joined,
            })
        return Response(data)

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        """Suspend a user."""
        try:
            user = User.objects.get(pk=pk)
            user.is_active = False
            user.save()
            return Response({'message': f'User {user.email} suspended'})
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        """Activate a user."""
        try:
            user = User.objects.get(pk=pk)
            user.is_active = True
            user.save()
            return Response({'message': f'User {user.email} activated'})
        except User.DoesNotExist:
            return Response(
                {'error': 'User not found'},
                status=status.HTTP_404_NOT_FOUND,
            )


class AdminStatisticsView(APIView):
    permission_classes = [permissions.IsAdminUser]

    def get(self, request):
        from donors.models import Donor
        from patients.models import Patient
        from requests.models import BloodRequest
        from donations.models import Donation
        from inventory.models import BloodInventory
        from appointments.models import Appointment
        from campaigns.models import Campaign
        from payments.models import Payment

        successful_payments = Payment.objects.filter(status='SUCCESS')
        total_revenue = successful_payments.aggregate(total=Sum('amount'))['total'] or 0.0
        sub_revenue = successful_payments.filter(payment_type='HOSPITAL_SUBSCRIPTION').aggregate(total=Sum('amount'))['total'] or 0.0
        req_revenue = successful_payments.filter(payment_type='BLOOD_REQUEST_PAYMENT').aggregate(total=Sum('amount'))['total'] or 0.0

        stats = {
            'total_users': User.objects.count(),
            'total_donors': Donor.objects.count(),
            'total_patients': Patient.objects.count(),
            'total_blood_requests': BloodRequest.objects.count(),
            'total_donations': Donation.objects.count(),
            'total_appointments': Appointment.objects.count(),
            'total_campaigns': Campaign.objects.count(),
            'pending_requests': BloodRequest.objects.filter(status='PENDING').count(),
            'completed_donations': Donation.objects.filter(status='COMPLETED').count(),
            'total_blood_units': BloodInventory.objects.aggregate(total=Sum('quantity'))['total'] or 0,
            'total_revenue': float(total_revenue),
            'subscription_revenue': float(sub_revenue),
            'request_revenue': float(req_revenue),
        }
        return Response(stats)
