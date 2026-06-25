from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import viewsets
from datetime import datetime, timedelta
from django.db.models import Sum, Count

from .models import Report
from .serializers import ReportSerializer


class ReportListView(generics.ListAPIView):
    serializer_class = ReportSerializer
    permission_classes = [permissions.IsAdminUser]

    def get_queryset(self):
        return Report.objects.all()


class ReportViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAdminUser]

    @action(detail=False, methods=['get'])
    def monthly_donations(self, request):
        """Get monthly donation statistics."""
        from donations.models import Donation
        from datetime import date

        year = request.query_params.get('year', date.today().year)
        try:
            year = int(year)
        except ValueError:
            return Response(
                {'error': 'Invalid year'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        monthly = []
        for month in range(1, 13):
            count = Donation.objects.filter(
                created_at__year=year,
                created_at__month=month,
                status='COMPLETED',
            ).count()
            monthly.append({'month': month, 'count': count})

        return Response({'year': year, 'monthly_donations': monthly})

    @action(detail=False, methods=['get'])
    def blood_stock(self, request):
        """Get blood stock grouped by blood group."""
        from inventory.models import BloodInventory

        stock = BloodInventory.objects.filter(status='available').values('blood_group').annotate(
            total=Sum('quantity'),
            count=Count('id'),
        ).order_by('blood_group')

        return Response({'stock_by_group': list(stock)})

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """Get overall statistics."""
        from donors.models import Donor
        from patients.models import Patient
        from requests.models import BloodRequest
        from donations.models import Donation
        from inventory.models import BloodInventory
        from appointments.models import Appointment
        from campaigns.models import Campaign

        stats = {
            'total_donors': Donor.objects.count(),
            'total_patients': Patient.objects.count(),
            'total_requests': BloodRequest.objects.count(),
            'total_donations': Donation.objects.count(),
            'total_appointments': Appointment.objects.count(),
            'total_campaigns': Campaign.objects.count(),
            'total_blood_units': BloodInventory.objects.aggregate(total=Sum('quantity'))['total'] or 0,
            'requests_by_status': list(
                BloodRequest.objects.values('status').annotate(count=Count('id')).order_by('status')
            ),
            'donations_by_status': list(
                Donation.objects.values('status').annotate(count=Count('id')).order_by('status')
            ),
        }
        return Response(stats)
