from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework import viewsets
from django.utils import timezone
from django.utils.decorators import method_decorator
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Q
import logging

from .models import Payment
from .serializers import PaymentSerializer
from .services import get_payment_provider

logger = logging.getLogger(__name__)



class PaymentListCreateView(generics.ListCreateAPIView):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['user', 'status', 'payment_method']


class PaymentDetailView(generics.RetrieveUpdateAPIView):
    queryset = Payment.objects.all()
    serializer_class = PaymentSerializer
    permission_classes = [permissions.IsAuthenticated]


class PaymentActionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['post'])
    def initiate(self, request):
        """Initiate a payment for a blood request via Mobile Money stub."""
        print("--- Complete Request Received by Django (/api/payments/initiate/) ---", flush=True)
        print(f"User: {request.user} (ID: {request.user.id if request.user else 'Anonymous'})", flush=True)
        print(f"Payload: {request.data}", flush=True)

        request_id = request.data.get('request_id')
        amount = request.data.get('amount')
        payment_method = request.data.get('payment_method')
        if payment_method == 'MTN':
            payment_method = 'MTN_MOMO'
        elif payment_method == 'ORANGE':
            payment_method = 'ORANGE_MONEY'
        phone_number = request.data.get('phone_number')

        if not all([request_id, amount, payment_method, phone_number]):
            return Response(
                {'error': 'request_id, amount, payment_method, and phone_number are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if payment_method not in ('MTN_MOMO', 'ORANGE_MONEY', 'CASH', 'CARD'):
            return Response(
                {'error': 'Unsupported payment method'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            from requests.models import BloodRequest
            blood_request = BloodRequest.objects.get(pk=request_id)
        except BloodRequest.DoesNotExist:
            return Response(
                {'error': 'Blood request not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        transaction_id = f'TXN-{request.user.id}-{blood_request.id}-{timezone.now().timestamp():.0f}'
        payment = Payment.objects.create(
            user=request.user,
            blood_request=blood_request,
            amount=amount,
            payment_method=payment_method,
            phone_number=phone_number,
            transaction_id=transaction_id,
            status='PENDING',
            payment_status='PENDING',
            payment_type='BLOOD_REQUEST_PAYMENT',
        )

        if payment_method in ('MTN_MOMO', 'ORANGE_MONEY'):
            try:
                provider = get_payment_provider(payment_method)
                result = provider.initiate(payment.amount, phone_number, transaction_id)
                payment.external_reference = result.external_reference
                payment.transaction_reference = result.external_reference
                payment.response_data = result.response_data
                payment.status = result.status
                payment.payment_status = result.status
                payment.save()
            except ValueError as exc:
                return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PaymentSerializer(payment)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def verify(self, request):
        """Verify a pending Mobile Money payment via Campay."""
        print("--- Complete Request Received by Django (/api/payments/verify/) ---", flush=True)
        print(f"User: {request.user} (ID: {request.user.id if request.user else 'Anonymous'})", flush=True)
        print(f"Payload: {request.data}", flush=True)

        payment_id = request.data.get('payment_id')
        if not payment_id:
            return Response({'error': 'payment_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payment = Payment.objects.get(pk=payment_id, user=request.user)
        except Payment.DoesNotExist:
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if payment.payment_method in ('MTN_MOMO', 'ORANGE_MONEY') and (payment.transaction_reference or payment.external_reference):
            ref_to_check = payment.transaction_reference or payment.external_reference
            provider = get_payment_provider(payment.payment_method)
            result = provider.verify(ref_to_check)
            payment.status = result.status
            payment.payment_status = result.status
            payment.response_data = result.response_data
            if result.status == 'SUCCESS':
                payment.paid_at = timezone.now()
            payment.save()

        serializer = PaymentSerializer(payment)
        return Response(serializer.data)


class PaymentHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        role = user.role.lower()
        
        # Auto-verify any pending payments before listing history
        from payments.models import verify_pending_payments
        try:
            if role == 'system_admin' or user.is_superuser:
                verify_pending_payments()
            elif role in ('hospital_staff', 'blood_bank_admin'):
                from hospitals.models import HospitalStaff
                staff_profile = HospitalStaff.objects.filter(user=user).first()
                if staff_profile and staff_profile.hospital:
                    verify_pending_payments(hospital=staff_profile.hospital)
            else:
                verify_pending_payments(user=user)
        except Exception:
            pass

        receipts = []

        if role == 'system_admin' or user.is_superuser:
            # System admin gets ALL payments and subscriptions
            payments = Payment.objects.all().select_related('hospital', 'blood_request')
            for p in payments:
                inv_num = p.invoices.first().invoice_number if p.invoices.exists() else f"RCPT-{p.id:04d}"
                receipts.append({
                    'id': p.id,
                    'receipt_number': p.transaction_id or inv_num,
                    'user_name': p.user.full_name if p.user else p.hospital.name if p.hospital else "System",
                    'user_role': p.user.role if p.user else "hospital_staff",
                    'created_at': p.created_at.isoformat(),
                    'payment_type': 'Hospital Subscription' if p.payment_type == 'HOSPITAL_SUBSCRIPTION' else 'Blood Request (Inventory)',
                    'description': f"Hospital subscription for {p.hospital.name}" if p.payment_type == 'HOSPITAL_SUBSCRIPTION' else f"Blood Request fulfill: {p.blood_request.quantity} Unit(s)" if p.blood_request else "Blood request fulfill payment",
                    'amount': float(p.amount),
                    'payment_method': p.payment_method,
                    'status': p.status,
                    'reference_id': inv_num,
                })
        elif role == 'patient':
            # Get all patient payments for blood requests
            payments = Payment.objects.filter(user=user, payment_type='BLOOD_REQUEST_PAYMENT').select_related('blood_request')
            for p in payments:
                receipts.append({
                    'id': p.id,
                    'receipt_number': p.transaction_id or f"RCPT-{p.id:04d}",
                    'user_name': user.full_name,
                    'user_role': 'Patient',
                    'created_at': p.created_at.isoformat(),
                    'payment_type': 'Blood Request (Inventory)',
                    'description': f"Blood Request Fulfill: {p.blood_request.quantity} Unit(s) of {p.blood_request.blood_group} blood." if p.blood_request else "Blood Request Fulfill Payment",
                    'amount': float(p.amount),
                    'payment_method': p.payment_method,
                    'status': p.status,
                    'reference_id': p.blood_request.id if p.blood_request else None,
                })
        elif role in ('hospital_staff', 'blood_bank_admin'):
            # Get staff hospital subscription payments
            from hospitals.models import HospitalStaff
            staff_profile = HospitalStaff.objects.filter(user=user).first()
            if staff_profile and staff_profile.hospital:
                subs = Payment.objects.filter(hospital=staff_profile.hospital, payment_type='HOSPITAL_SUBSCRIPTION')
                for s in subs:
                    inv_num = s.invoices.first().invoice_number if s.invoices.exists() else f"INV-SUB-{s.id:04d}"
                    receipts.append({
                        'id': s.id,
                        'receipt_number': s.transaction_id or inv_num,
                        'user_name': user.full_name,
                        'user_role': 'Hospital Staff',
                        'created_at': s.created_at.isoformat(),
                        'payment_type': 'Hospital Subscription',
                        'description': f"Hospital subscription renew: {max(1, int(s.amount // 25))} Months plan.",
                        'amount': float(s.amount),
                        'payment_method': s.payment_method,
                        'status': s.status,
                        'reference_id': inv_num,
                    })

        # Sort receipts by date descending
        receipts.sort(key=lambda x: x['created_at'], reverse=True)
        return Response(receipts, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name='dispatch')
class CampayWebhookView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        logger.info(f"Campay webhook payload received: {request.data}")
        ref = request.data.get('reference')
        status_raw = request.data.get('status')
        ext_ref = request.data.get('external_reference')

        if not ref:
            return Response({'error': 'Reference missing'}, status=status.HTTP_400_BAD_REQUEST)

        # Lookup payment record (using Campay reference or internal reference keys)
        payment = Payment.objects.filter(Q(transaction_reference=ref) | Q(transaction_id=ext_ref) | Q(external_reference=ref)).first()
        if not payment:
            # Fallback to direct check on transaction_reference
            payment = Payment.objects.filter(transaction_reference=ref).first()

        if not payment:
            logger.error(f"Campay webhook payment not found for reference: {ref}")
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)

        # Secure Verification: Verify status directly against Campay gateway endpoint
        provider = get_payment_provider(payment.payment_method)
        result = provider.verify(ref)

        if result.status == 'SUCCESS':
            payment.status = 'SUCCESS'
            payment.payment_status = 'SUCCESS'
            payment.paid_at = timezone.now()
            payment.response_data = result.response_data
            payment.save()
            logger.info(f"Campay payment {payment.transaction_id} verified successfully via webhook.")
        elif result.status == 'FAILED':
            payment.status = 'FAILED'
            payment.payment_status = 'FAILED'
            payment.response_data = result.response_data
            payment.save()
            logger.info(f"Campay payment {payment.transaction_id} marked FAILED via webhook.")

        return Response({'status': 'acknowledged'}, status=status.HTTP_200_OK)

