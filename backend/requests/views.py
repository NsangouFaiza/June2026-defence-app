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

    def get_queryset(self):
        from payments.models import verify_pending_payments
        try:
            if self.request.user and self.request.user.is_authenticated:
                if self.request.user.role == 'system_admin' or self.request.user.is_superuser:
                    verify_pending_payments()
                elif hasattr(self.request.user, 'hospital_staff'):
                    verify_pending_payments(hospital=self.request.user.hospital_staff.hospital)
                else:
                    verify_pending_payments(user=self.request.user)
        except Exception:
            pass
        return super().get_queryset()

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
        from payments.models import verify_pending_payments
        try:
            verify_pending_payments(user=request.user)
        except Exception:
            pass

        from patients.models import Patient
        patient, _ = Patient.objects.get_or_create(user=request.user)
        queryset = BloodRequest.objects.filter(patient=patient)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve a blood request (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Unauthorized: Only hospital staff and administrators can approve blood requests.'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()

        # Check staff hospital assignment
        staff_profile = getattr(request.user, 'hospital_staff', None)
        if not staff_profile and request.user.role in ('hospital_staff', 'blood_bank_admin'):
            from hospitals.models import HospitalStaff
            staff_profile = HospitalStaff.objects.filter(user=request.user).first()

        if staff_profile and staff_profile.hospital and blood_request.hospital:
            if request.user.role != 'system_admin' and staff_profile.hospital.id != blood_request.hospital.id:
                return Response(
                    {'error': f'Unauthorized: You are assigned to {staff_profile.hospital.name}, but this request is assigned to {blood_request.hospital.name}.'},
                    status=status.HTTP_403_FORBIDDEN
                )

        # Check hospital active subscription
        if blood_request.hospital and not blood_request.hospital.is_subscription_active:
            return Response(
                {'error': f'Unable to approve this request: {blood_request.hospital.name} does not have an active subscription.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if blood_request.status in ('APPROVED', 'FULFILLED', 'REJECTED', 'CANCELLED'):
            return Response(
                {'error': f'Unable to approve this request: request has already been {blood_request.status.lower()}.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        fulfillment_type = request.data.get('fulfillment_type')
        if not fulfillment_type or fulfillment_type not in ('DIRECT_DONATION', 'INVENTORY'):
            return Response(
                {'error': 'Unable to approve this request: fulfillment source must be specified as either DIRECT_DONATION or INVENTORY.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if fulfillment_type == 'INVENTORY':
            from inventory.models import BloodInventory
            from django.db.models import Sum
            from django.utils import timezone
            import uuid

            now_date = timezone.now().date()
            total_available = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available',
                expiration_date__gte=now_date
            ).aggregate(total=Sum('quantity'))['total'] or 0

            if total_available < blood_request.quantity:
                return Response(
                    {'error': f"Unable to approve this request: insufficient blood inventory. Only {total_available} unit(s) of {blood_request.blood_group} blood available, but {blood_request.quantity} unit(s) requested."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Check if an invoice is already pending
            from payments.models import Payment
            existing_invoice = Payment.objects.filter(
                blood_request=blood_request,
                status='PENDING'
            ).first()

            if blood_request.fulfillment_type == 'INVENTORY' and blood_request.payment_status == 'PENDING' and existing_invoice:
                return Response(
                    {'error': f'Unable to approve this request: an invoice for 25 FCFA (Ref: {existing_invoice.transaction_id}) is already pending patient payment.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Mark request as pending payment
            blood_request.status = 'PENDING'
            blood_request.payment_status = 'PENDING'
            blood_request.fulfillment_type = 'INVENTORY'
            blood_request.donor = None
            blood_request.processed_by = request.user
            blood_request.save()

            if not existing_invoice:
                transaction_id = f'INV-{blood_request.patient.user.id}-{blood_request.id}-{int(timezone.now().timestamp())}-{uuid.uuid4().hex[:4].upper()}'
                Payment.objects.create(
                    user=blood_request.patient.user,
                    blood_request=blood_request,
                    hospital=blood_request.hospital,
                    amount=25.0,
                    payment_method='MTN_MOMO',
                    transaction_id=transaction_id,
                    status='PENDING',
                    payment_status='PENDING',
                    payment_type='BLOOD_REQUEST_PAYMENT',
                )

            from audit.models import AuditLog
            AuditLog.objects.create(
                user=request.user,
                action='UPDATE',
                model_name='BloodRequest',
                object_id=str(blood_request.id),
                description=f"Staff approved blood request from inventory. 25 FCFA processing invoice pending patient payment.",
                changes={'fulfillment_type': 'INVENTORY', 'status': 'PENDING', 'payment_status': 'PENDING'}
            )

        else: # DIRECT_DONATION
            donor_id = request.data.get('donor_id')
            assigned_donor = None
            if donor_id:
                from donors.models import Donor
                try:
                    assigned_donor = Donor.objects.get(pk=donor_id)
                    blood_request.donor = assigned_donor
                except Donor.DoesNotExist:
                    return Response({'error': 'Unable to approve this request: specified donor was not found.'}, status=status.HTTP_400_BAD_REQUEST)
            else:
                blood_request.donor = None

            blood_request.status = 'APPROVED'
            blood_request.payment_status = 'PAID'
            blood_request.fulfillment_type = 'DIRECT_DONATION'
            blood_request.processed_by = request.user
            blood_request.save()

            if assigned_donor:
                self._schedule_direct_donation_appointment(blood_request, assigned_donor)

            from audit.models import AuditLog
            AuditLog.objects.create(
                user=request.user,
                action='APPROVE',
                model_name='BloodRequest',
                object_id=str(blood_request.id),
                description="Staff approved blood request as direct donation (free).",
                changes={'fulfillment_type': 'DIRECT_DONATION', 'status': 'APPROVED', 'payment_status': 'PAID'}
            )

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
                assigned_donor = None
                if donor_id:
                    from donors.models import Donor
                    try:
                        assigned_donor = Donor.objects.get(pk=donor_id)
                        blood_request.donor = assigned_donor
                        blood_request.save()
                    except Donor.DoesNotExist:
                        return Response({'error': 'Invalid donor ID'}, status=status.HTTP_400_BAD_REQUEST)
                elif 'donor_id' in request.data:
                    blood_request.donor = None
                    blood_request.save()

                if assigned_donor:
                    self._schedule_direct_donation_appointment(blood_request, assigned_donor)
                    
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
            return Response({'error': 'Unauthorized: Only hospital staff and administrators can fulfill blood requests.'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()

        staff_profile = getattr(request.user, 'hospital_staff', None)
        if not staff_profile and request.user.role in ('hospital_staff', 'blood_bank_admin'):
            from hospitals.models import HospitalStaff
            staff_profile = HospitalStaff.objects.filter(user=request.user).first()

        if staff_profile and staff_profile.hospital and blood_request.hospital:
            if request.user.role != 'system_admin' and staff_profile.hospital.id != blood_request.hospital.id:
                return Response(
                    {'error': f'Unauthorized: You are assigned to {staff_profile.hospital.name}, but this request belongs to {blood_request.hospital.name}.'},
                    status=status.HTTP_403_FORBIDDEN
                )

        if blood_request.status == 'FULFILLED':
            return Response({'error': 'This blood request has already been marked as fulfilled.'}, status=status.HTTP_400_BAD_REQUEST)

        if blood_request.fulfillment_type == 'INVENTORY' and blood_request.payment_status != 'PAID':
            return Response(
                {'error': 'Unable to fulfill request: the 25 FCFA processing invoice must be paid by the patient before fulfillment.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if blood_request.fulfillment_type == 'INVENTORY':
            from inventory.models import BloodInventory
            from django.utils import timezone
            inv_units = BloodInventory.objects.filter(
                hospital=blood_request.hospital,
                blood_group=blood_request.blood_group,
                status='available',
                expiration_date__gte=timezone.now().date()
            ).order_by('expiration_date')

            needed = blood_request.quantity
            total_avail = sum(u.quantity for u in inv_units)
            if total_avail < needed:
                return Response(
                    {'error': f'Unable to fulfill request: insufficient blood inventory units in stock ({total_avail} available, {needed} required).'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            for unit in inv_units:
                if needed <= 0:
                    break
                if unit.quantity <= needed:
                    needed -= unit.quantity
                    unit.quantity = 0
                    unit.status = 'used'
                    unit.save()
                else:
                    unit.quantity -= needed
                    needed = 0
                    unit.save()

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

    def _schedule_direct_donation_appointment(self, blood_request, donor):
        from appointments.models import Appointment
        from notifications.models import Notification
        from datetime import timedelta
        from django.utils import timezone
        
        # Check if an appointment already exists for this blood request
        appointment = Appointment.objects.filter(blood_request=blood_request).first()
        tomorrow = timezone.now().date() + timedelta(days=1)
        
        if not appointment:
            appointment = Appointment.objects.create(
                donor=donor,
                hospital=blood_request.hospital,
                blood_request=blood_request,
                scheduled_date=tomorrow,
                scheduled_time="09:00:00",
                status='SCHEDULED',
                notes=f"Automatically scheduled for Direct Donation blood request #{blood_request.id}."
            )
            
            # Notify Donor
            Notification.objects.create(
                recipient=donor.user,
                notification_type='APPOINTMENT_REMINDER',
                title='Direct Donation Scheduled / Don Direct Planifié',
                message=f"An emergency appointment has been scheduled for you to donate blood at {blood_request.hospital.name} for request ref #{blood_request.id}.\nDate: {tomorrow}\nTime: 09:00 AM\nLocation: {blood_request.hospital.address or 'Hospital Clinic'}.",
                data={'blood_request_id': blood_request.id, 'appointment_id': appointment.id}
            )
            
            # Notify Patient
            Notification.objects.create(
                recipient=blood_request.patient.user,
                notification_type='REQUEST_UPDATE',
                title='Donor Assigned & Appointment Scheduled / Donneur Assigné & RDV Planifié',
                message=f"A compatible donor ({donor.user.full_name}) has been assigned to your blood request ref #{blood_request.id}.\nAppointment Scheduled at {blood_request.hospital.name}.\nDate: {tomorrow}\nTime: 09:00 AM.",
                data={'blood_request_id': blood_request.id, 'appointment_id': appointment.id}
            )
        else:
            if appointment.donor != donor:
                appointment.donor = donor
                appointment.save()
                
                # Notify New Donor
                Notification.objects.create(
                    recipient=donor.user,
                    notification_type='APPOINTMENT_REMINDER',
                    title='Direct Donation Scheduled / Don Direct Planifié',
                    message=f"You have been assigned to donate blood for request ref #{blood_request.id} at {blood_request.hospital.name}.\nDate: {appointment.scheduled_date}\nTime: {appointment.scheduled_time}\nLocation: {blood_request.hospital.address or 'Hospital Clinic'}.",
                    data={'blood_request_id': blood_request.id, 'appointment_id': appointment.id}
                )

