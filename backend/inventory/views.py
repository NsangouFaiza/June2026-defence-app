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
            request.user.role in ('hospital_staff', 'blood_bank_admin', 'system_admin')
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
        if self.action in ['list', 'retrieve', 'search', 'check_availability']:
            return [permissions.AllowAny()]
        return [IsStaffOrTechnicianOrAdmin()]

    @action(detail=False, methods=['get'])
    def search(self, request):
        """Search blood inventory by filters."""
        from django.utils import timezone
        now = timezone.now()
        blood_group = request.query_params.get('blood_group')
        region = request.query_params.get('region')
        hospital_id = request.query_params.get('hospital')

        queryset = BloodInventory.objects.filter(
            status='available',
            expiration_date__gte=now.date(),
            hospital__is_active=True,
            hospital__subscription_status='ACTIVE',
            hospital__subscription_end_date__gte=now
        )

        if blood_group:
            queryset = queryset.filter(blood_group=blood_group)
        if region:
            queryset = queryset.filter(hospital__region=region)
        if hospital_id:
            queryset = queryset.filter(hospital_id=hospital_id)

        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get', 'post'], url_path='check_availability')
    def check_availability(self, request):
        """Check blood availability across active/paid hospitals for patient."""
        from django.utils import timezone
        from django.db.models import Sum

        data = request.data if request.method == 'POST' else request.query_params
        blood_group = data.get('blood_group')
        quantity_raw = data.get('quantity', 1)
        try:
            quantity = int(quantity_raw)
            if quantity <= 0:
                quantity = 1
        except (ValueError, TypeError):
            quantity = 1

        if not blood_group:
            return Response(
                {'error': 'Blood group is required to check blood availability.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        now = timezone.now()
        today = now.date()

        # Query available units in hospitals that have an active subscription
        hospitals_with_blood = (
            BloodInventory.objects.filter(
                status='available',
                expiration_date__gte=today,
                blood_group=blood_group,
                hospital__is_active=True,
                hospital__subscription_status='ACTIVE',
                hospital__subscription_end_date__gte=now,
            )
            .values(
                'hospital__id',
                'hospital__name',
                'hospital__address',
                'hospital__city',
                'hospital__region',
                'hospital__phone_number',
                'hospital__email',
                'hospital__has_emergency_services',
                'hospital__latitude',
                'hospital__longitude',
            )
            .annotate(available_units=Sum('quantity'))
            .filter(available_units__gt=0)
            .order_by('-available_units')
        )

        results = []
        for h in hospitals_with_blood:
            avail = h['available_units'] or 0
            results.append({
                'hospital_id': h['hospital__id'],
                'hospital_name': h['hospital__name'],
                'address': h['hospital__address'] or '',
                'city': h['hospital__city'] or '',
                'region': h['hospital__region'] or '',
                'phone_number': h['hospital__phone_number'] or '',
                'email': h['hospital__email'] or '',
                'has_emergency_services': h['hospital__has_emergency_services'] or False,
                'latitude': h['hospital__latitude'],
                'longitude': h['hospital__longitude'],
                'blood_group': blood_group,
                'available_units': avail,
                'requested_quantity': quantity,
                'is_sufficient': avail >= quantity,
            })

        return Response({
            'blood_group': blood_group,
            'requested_quantity': quantity,
            'total_hospitals_found': len(results),
            'hospitals': results,
        }, status=status.HTTP_200_OK)

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
        """Staff or admin approves a blood unit for inventory."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        unit = self.get_object()
        unit.status = 'available'
        unit.save()
        return Response(self.get_serializer(unit).data)

    @action(detail=True, methods=['post'])
    def reject_unit(self, request, pk=None):
        """Staff or admin rejects a blood unit."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        unit = self.get_object()
        unit.status = 'rejected'
        unit.save()
        return Response(self.get_serializer(unit).data)


from .models import LabTestRecord
from .serializers import LabTestRecordSerializer

class LabTestRecordViewSet(viewsets.ModelViewSet):
    """ViewSet for LabTestRecord model."""

    queryset = LabTestRecord.objects.all()
    serializer_class = LabTestRecordSerializer
    permission_classes = [IsStaffOrTechnicianOrAdmin]
    filterset_fields = ['donor', 'blood_group', 'unit_status', 'has_abnormal_findings']
    search_fields = ['sample_code', 'donor__user__full_name', 'abnormal_findings']

    def perform_create(self, serializer):
        serializer.save(tested_by=self.request.user)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve lab record & update inventory unit status to available."""
        lab_record = self.get_object()
        lab_record.unit_status = 'APPROVED'
        lab_record.save()

        if lab_record.inventory_unit:
            unit = lab_record.inventory_unit
            unit.status = 'available'
            unit.save()

        serializer = self.get_serializer(lab_record)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject lab record & update inventory unit status to rejected."""
        lab_record = self.get_object()
        reason = request.data.get('reason', '')
        lab_record.unit_status = 'REJECTED'
        if reason:
            lab_record.abnormal_findings = f"{lab_record.abnormal_findings}\nRejection note: {reason}".strip()
            lab_record.has_abnormal_findings = True
        lab_record.save()

        if lab_record.inventory_unit:
            unit = lab_record.inventory_unit
            unit.status = 'rejected'
            unit.save()

        serializer = self.get_serializer(lab_record)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def report_abnormal(self, request, pk=None):
        """Report abnormal finding for a sample."""
        lab_record = self.get_object()
        findings = request.data.get('abnormal_findings', '')
        unit_status = request.data.get('unit_status', 'QUARANTINED')

        lab_record.has_abnormal_findings = True
        lab_record.abnormal_findings = findings
        lab_record.unit_status = unit_status
        lab_record.save()

        if lab_record.inventory_unit and unit_status in ('REJECTED', 'QUARANTINED'):
            unit = lab_record.inventory_unit
            unit.status = 'rejected' if unit_status == 'REJECTED' else 'reserved'
            unit.save()

        serializer = self.get_serializer(lab_record)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_tests(self, request):
        """Get lab tests conducted by current technician."""
        records = LabTestRecord.objects.filter(tested_by=request.user)
        serializer = self.get_serializer(records, many=True)
        return Response(serializer.data)

