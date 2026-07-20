from django.db.models import Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import BloodRequest
from .serializers import BloodRequestSerializer


class BloodRequestViewSet(viewsets.ModelViewSet):
    """ViewSet for BloodRequest model."""

    queryset = BloodRequest.objects.all()
    serializer_class = BloodRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['patient', 'hospital', 'blood_group', 'status', 'urgency']
    search_fields = ['patient__user__first_name', 'patient__user__last_name', 'hospital__name']

    def perform_create(self, serializer):
        from patients.models import Patient
        patient, _ = Patient.objects.get_or_create(user=self.request.user)
        serializer.save(patient=patient)

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'emergency']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    @action(detail=False, methods=['get', 'post'], url_path='emergency')
    def emergency(self, request):
        """Get or create emergency blood requests."""
        if request.method == 'POST':
            from patients.models import Patient
            patient, _ = Patient.objects.get_or_create(user=request.user)

            data = request.data.copy()
            data['is_emergency'] = True
            data['urgency'] = 'CRITICAL'
            if 'hospital_id' not in data or not data['hospital_id']:
                from hospitals.models import Hospital
                first_hospital = Hospital.objects.first()
                if first_hospital:
                    data['hospital_id'] = first_hospital.id
            
            serializer = self.get_serializer(data=data)
            if serializer.is_valid():
                serializer.save(patient=patient)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # GET method
        queryset = BloodRequest.objects.filter(
            is_emergency=True,
            status__in=['PENDING', 'APPROVED', 'PROCESSING'],
        ).order_by('-urgency', '-created_at')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_requests(self, request):
        """Get current patient's requests."""
        from patients.models import Patient
        patient, _ = Patient.objects.get_or_create(user=request.user)
        queryset = BloodRequest.objects.filter(patient=patient)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve a blood request (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        
        fulfillment_type = request.data.get('fulfillment_type')
        if not fulfillment_type or fulfillment_type not in ('DIRECT_DONATION', 'INVENTORY'):
            return Response(
                {'error': 'Fulfillment type must be specified: either DIRECT_DONATION or INVENTORY.'},
                status=status.HTTP_400_BAD_REQUEST
            )
            
        if fulfillment_type == 'INVENTORY':
            # Check hospital inventory for available blood units matching the group
            from inventory.models import BloodInventory
            from django.db.models import Sum
            
            total_available = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available'
            ).aggregate(total=Sum('quantity'))['total'] or 0
            
            if total_available < blood_request.quantity:
                return Response(
                    {'error': f"Insufficient inventory: Only {total_available} unit(s) of {blood_request.blood_group} blood available, but {blood_request.quantity} unit(s) requested."},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
            # Decrement from inventory
            remaining_to_deduct = blood_request.quantity
            matching_inventories = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available'
            ).order_by('expiration_date')
            
            for inv in matching_inventories:
                if remaining_to_deduct <= 0:
                    break
                if inv.quantity >= remaining_to_deduct:
                    inv.quantity -= remaining_to_deduct
                    if inv.quantity == 0:
                        inv.status = 'used'
                    inv.save()
                    remaining_to_deduct = 0
                else:
                    remaining_to_deduct -= inv.quantity
                    inv.quantity = 0
                    inv.status = 'used'
                    inv.save()
                    
        if fulfillment_type == 'DIRECT_DONATION':
            donor_id = request.data.get('donor_id')
            if donor_id:
                from donors.models import Donor
                try:
                    blood_request.donor = Donor.objects.get(pk=donor_id)
                except Donor.DoesNotExist:
                    return Response({'error': 'Invalid donor ID'}, status=status.HTTP_400_BAD_REQUEST)
            else:
                blood_request.donor = None
        else:
            blood_request.donor = None

        blood_request.status = 'APPROVED'
        blood_request.fulfillment_type = fulfillment_type
        blood_request.save()
        
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='update-fulfillment')
    def update_fulfillment(self, request, pk=None):
        """Update the fulfillment type and handle inventory changes (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        
        new_type = request.data.get('fulfillment_type')
        if not new_type or new_type not in ('DIRECT_DONATION', 'INVENTORY'):
            return Response(
                {'error': 'Fulfillment type must be specified: either DIRECT_DONATION or INVENTORY.'},
                status=status.HTTP_400_BAD_REQUEST
            )
            
        old_type = blood_request.fulfillment_type
        if old_type == new_type:
            # If remaining in direct donation, check if they are just assigning/updating a donor
            if new_type == 'DIRECT_DONATION':
                donor_id = request.data.get('donor_id')
                if donor_id:
                    from donors.models import Donor
                    try:
                        blood_request.donor = Donor.objects.get(pk=donor_id)
                        blood_request.save()
                    except Donor.DoesNotExist:
                        return Response({'error': 'Invalid donor ID'}, status=status.HTTP_400_BAD_REQUEST)
                elif 'donor_id' in request.data:
                    blood_request.donor = None
                    blood_request.save()
                    
            serializer = self.get_serializer(blood_request)
            return Response(serializer.data)
            
        # Toggling from DIRECT_DONATION to INVENTORY:
        if new_type == 'INVENTORY':
            # Check hospital inventory
            from inventory.models import BloodInventory
            from django.db.models import Sum
            
            total_available = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available'
            ).aggregate(total=Sum('quantity'))['total'] or 0
            
            if total_available < blood_request.quantity:
                return Response(
                    {'error': f"Insufficient inventory: Only {total_available} unit(s) of {blood_request.blood_group} blood available, but {blood_request.quantity} unit(s) requested."},
                    status=status.HTTP_400_BAD_REQUEST
                )
                
            # Decrement from inventory
            remaining_to_deduct = blood_request.quantity
            matching_inventories = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available'
            ).order_by('expiration_date')
            
            for inv in matching_inventories:
                if remaining_to_deduct <= 0:
                    break
                if inv.quantity >= remaining_to_deduct:
                    inv.quantity -= remaining_to_deduct
                    if inv.quantity == 0:
                        inv.status = 'used'
                    inv.save()
                    remaining_to_deduct = 0
                else:
                    remaining_to_deduct -= inv.quantity
                    inv.quantity = 0
                    inv.status = 'used'
                    inv.save()
            
            # Clear donor since it's now fulfilled from inventory
            blood_request.donor = None
            
        # Toggling from INVENTORY to DIRECT_DONATION:
        elif new_type == 'DIRECT_DONATION':
            # Refund the inventory back to the hospital
            from inventory.models import BloodInventory
            from datetime import date, timedelta
            
            today = date.today()
            inv_record, created = BloodInventory.objects.get_or_create(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                collection_date=today,
                defaults={
                    'quantity': blood_request.quantity,
                    'expiration_date': today + timedelta(days=42),
                    'status': 'available'
                }
            )
            if not created:
                inv_record.quantity += blood_request.quantity
                if inv_record.status == 'used':
                    inv_record.status = 'available'
                inv_record.save()
                
            # Assign optional donor
            donor_id = request.data.get('donor_id')
            if donor_id:
                from donors.models import Donor
                try:
                    blood_request.donor = Donor.objects.get(pk=donor_id)
                except Donor.DoesNotExist:
                    return Response({'error': 'Invalid donor ID'}, status=status.HTTP_400_BAD_REQUEST)
            else:
                blood_request.donor = None

        blood_request.fulfillment_type = new_type
        blood_request.save()
        
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject a blood request (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        reason = request.data.get('reason', '')
        blood_request.status = 'REJECTED'
        blood_request.reason = reason
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def fulfill(self, request, pk=None):
        """Mark request as fulfilled (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        blood_request.status = 'FULFILLED'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def pledge(self, request, pk=None):
        """Pledge to donate for a blood request (Donor)."""
        blood_request = self.get_object()
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
        except Donor.DoesNotExist:
            return Response({'error': 'Donor profile required to pledge.'}, status=status.HTTP_400_BAD_REQUEST)

        blood_request.donor = donor
        if blood_request.status == 'PENDING':
            blood_request.status = 'APPROVED'
            blood_request.fulfillment_type = 'DIRECT_DONATION'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_pledges(self, request):
        """Get requests pledged by current donor."""
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
            queryset = BloodRequest.objects.filter(donor=donor)
            serializer = self.get_serializer(queryset, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response([])

    @action(detail=True, methods=['post'])
    def cancel_pledge(self, request, pk=None):
        """Cancel donor's pledge on a blood request."""
        blood_request = self.get_object()
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
            if blood_request.donor == donor:
                blood_request.donor = None
                blood_request.save()
        except Donor.DoesNotExist:
            pass
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

