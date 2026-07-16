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


class IsStaffOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and (
            request.user.is_staff
            or request.user.role in ('hospital_staff', 'blood_bank_admin', 'system_admin', 'lab_technician')
        )


class ReportViewSet(viewsets.ViewSet):
    permission_classes = [IsStaffOrAdmin]

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

    @action(detail=False, methods=['get'], url_path='explorer')
    def report_explorer(self, request):
        """Get data for the Report Explorer."""
        start_date = request.query_params.get('start_date')
        end_date = request.query_params.get('end_date')
        search_query = request.query_params.get('search', '').strip()
        report_type = request.query_params.get('type')

        from django.utils.dateparse import parse_date
        parsed_start = parse_date(start_date) if start_date else None
        parsed_end = parse_date(end_date) if end_date else None

        from inventory.models import BloodInventory
        from donations.models import Donation
        from donors.models import Donor
        from requests.models import BloodRequest
        from django.db.models import Q

        # Base queries
        inventory_qs = BloodInventory.objects.all()
        donation_qs = Donation.objects.filter(status='COMPLETED')
        donor_qs = Donor.objects.all()
        request_qs = BloodRequest.objects.all()

        # Apply date filters
        if parsed_start:
            inventory_qs = inventory_qs.filter(created_at__date__gte=parsed_start)
            donation_qs = donation_qs.filter(created_at__date__gte=parsed_start)
            donor_qs = donor_qs.filter(created_at__date__gte=parsed_start)
            request_qs = request_qs.filter(created_at__date__gte=parsed_start)
        if parsed_end:
            inventory_qs = inventory_qs.filter(created_at__date__lte=parsed_end)
            donation_qs = donation_qs.filter(created_at__date__lte=parsed_end)
            donor_qs = donor_qs.filter(created_at__date__lte=parsed_end)
            request_qs = request_qs.filter(created_at__date__lte=parsed_end)

        # Apply search query
        if search_query:
            inventory_qs = inventory_qs.filter(Q(blood_group__icontains=search_query) | Q(hospital__name__icontains=search_query))
            donation_qs = donation_qs.filter(Q(blood_group__icontains=search_query) | Q(donor__user__full_name__icontains=search_query))
            donor_qs = donor_qs.filter(Q(user__full_name__icontains=search_query) | Q(user__email__icontains=search_query))
            request_qs = request_qs.filter(Q(blood_group__icontains=search_query) | Q(patient__user__full_name__icontains=search_query) | Q(hospital__name__icontains=search_query))

        data = {}

        if report_type == 'INVENTORY':
            groups = inventory_qs.values('blood_group', 'status').annotate(total=Sum('quantity'), count=Count('id')).order_by('blood_group')
            data['rows'] = list(groups)
            
        elif report_type == 'EXPIRATION':
            from django.utils import timezone
            today = timezone.now().date()
            soon = today + timedelta(days=30)
            
            expired_items = inventory_qs.filter(
                Q(expiration_date__lt=today) | Q(status='expired')
            )
            expiring_soon_items = inventory_qs.filter(
                expiration_date__range=(today, soon), status='available'
            )
            
            expired_list = [{
                'id': x.id,
                'hospital': x.hospital.name,
                'blood_group': x.blood_group,
                'quantity': x.quantity,
                'expiration_date': str(x.expiration_date),
                'status': 'Expired'
            } for x in expired_items]
            
            expiring_soon_list = [{
                'id': x.id,
                'hospital': x.hospital.name,
                'blood_group': x.blood_group,
                'quantity': x.quantity,
                'expiration_date': str(x.expiration_date),
                'status': f"Expiring in {(x.expiration_date - today).days} days"
            } for x in expiring_soon_items]
            
            data['expired'] = expired_list
            data['expiring_soon'] = expiring_soon_list
            
        elif report_type == 'DONATION':
            donations = donation_qs.values('created_at__date').annotate(count=Count('id'), total_ml=Sum('quantity_ml')).order_by('created_at__date')
            data['rows'] = list(donations)
            
        elif report_type == 'USAGE':
            issued = request_qs.filter(status='FULFILLED').values('hospital__name', 'blood_group').annotate(total_issued=Sum('quantity'), count=Count('id')).order_by('blood_group')
            data['rows'] = list(issued)
            
        elif report_type == 'DONOR':
            total_donors = donor_qs.count()
            eligible_donors = donor_qs.filter(is_eligible=True).count()
            active_donors = donor_qs.filter(total_donations__gt=0).count()
            
            donor_list = [{
                'id': d.id,
                'name': d.user.full_name,
                'email': d.user.email,
                'phone': d.user.phone_number,
                'blood_group': d.blood_group or d.user.blood_group or 'N/A',
                'is_eligible': d.is_eligible,
                'total_donations': d.total_donations
            } for d in donor_qs]
            
            data['summary'] = {
                'total': total_donors,
                'eligible': eligible_donors,
                'active': active_donors
            }
            data['donors'] = donor_list
            
        elif report_type == 'REQUEST':
            req_status = request_qs.values('status').annotate(count=Count('id'), total_qty=Sum('quantity')).order_by('status')
            data['rows'] = list(req_status)
            
        elif report_type == 'WASTAGE':
            wastage = inventory_qs.filter(status__in=['expired', 'rejected'])
            wastage_list = [{
                'id': x.id,
                'hospital': x.hospital.name,
                'blood_group': x.blood_group,
                'quantity': x.quantity,
                'status': x.status,
                'collection_date': str(x.collection_date),
                'expiration_date': str(x.expiration_date),
            } for x in wastage]
            data['rows'] = wastage_list
            
        elif report_type == 'EMERGENCY':
            emergencies = request_qs.filter(is_emergency=True)
            emergency_list = [{
                'id': x.id,
                'patient': x.patient.user.full_name,
                'hospital': x.hospital.name,
                'blood_group': x.blood_group,
                'quantity': x.quantity,
                'urgency': x.urgency,
                'status': x.status,
                'created_at': str(x.created_at)
            } for x in emergencies]
            data['rows'] = emergency_list
            
        elif report_type == 'SUMMARY':
            total_completed_donations = Donation.objects.filter(status='COMPLETED').count()
            units_collected = BloodInventory.objects.aggregate(total=Sum('quantity'))['total'] or 0
            units_issued = BloodRequest.objects.filter(status='FULFILLED').aggregate(total=Sum('quantity'))['total'] or 0
            current_stock = BloodInventory.objects.filter(status='available').aggregate(total=Sum('quantity'))['total'] or 0
            
            data['summary'] = {
                'total_donations': total_completed_donations,
                'units_collected': units_collected,
                'units_issued': units_issued,
                'current_stock': current_stock
            }
            
        return Response(data)
