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
        transaction_id = request.data.get('transaction_id')
        reference = request.data.get('reference')
        
        q = Q()
        if payment_id:
            q |= Q(pk=payment_id)
        if transaction_id:
            q |= Q(transaction_id=transaction_id)
        if reference:
            q |= Q(transaction_reference=reference) | Q(external_reference=reference)
            
        if not q:
            return Response({'error': 'payment_id, transaction_id, or reference is required'}, status=status.HTTP_400_BAD_REQUEST)

        payment = Payment.objects.filter(q).first()
        if not payment:
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if payment.transaction_reference or payment.external_reference or payment.transaction_id:
            ref_to_check = payment.transaction_reference or payment.external_reference or payment.transaction_id
            provider = get_payment_provider(payment.payment_method)
            result = provider.verify(ref_to_check)
            if result.status == 'SUCCESS':
                from .services import process_successful_payment
                payment = process_successful_payment(
                    payment_id=payment.id,
                    transaction_reference=ref_to_check,
                    phone_number=payment.phone_number,
                    payment_method=payment.payment_method,
                    amount=payment.amount,
                    paid_at=timezone.now(),
                    response_data=result.response_data
                )
            else:
                payment.status = result.status
                payment.payment_status = result.status
                payment.response_data = result.response_data
                payment.save()

        serializer = PaymentSerializer(payment)
        return Response(serializer.data)


class PaymentHistoryView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        role = user.role.lower() if user.role else 'patient'
        
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
                h_name = p.hospital.name if p.hospital else (p.blood_request.hospital.name if p.blood_request and p.blood_request.hospital else "N/A")
                sub_period = f"{max(1, int(p.amount // 25))} Month(s)" if p.payment_type == 'HOSPITAL_SUBSCRIPTION' else None
                receipts.append({
                    'id': p.id,
                    'receipt_number': p.receipts.first().receipt_number if p.receipts.exists() else (p.transaction_id or inv_num),
                    'transaction_reference': p.transaction_reference or p.external_reference or p.transaction_id or "N/A",
                    'user_name': p.user.full_name if p.user else (p.hospital.name if p.hospital else "System"),
                    'user_role': p.user.role if p.user else "hospital_staff",
                    'created_at': p.created_at.isoformat(),
                    'payment_type': 'Hospital Subscription' if p.payment_type == 'HOSPITAL_SUBSCRIPTION' else 'Blood Request Payment',
                    'description': f"Hospital subscription for {p.hospital.name}" if p.payment_type == 'HOSPITAL_SUBSCRIPTION' else f"Blood Request fulfill: {p.blood_request.quantity} Unit(s)" if p.blood_request else "Blood request fulfill payment",
                    'amount': float(p.amount),
                    'payment_method': p.payment_method,
                    'status': p.status,
                    'reference_id': inv_num,
                    'hospital_name': h_name,
                    'subscription_period': sub_period,
                })
        elif role == 'patient':
            # Get all patient payments for blood requests
            payments = Payment.objects.filter(user=user, payment_type='BLOOD_REQUEST_PAYMENT').select_related('blood_request')
            for p in payments:
                inv_num = p.invoices.first().invoice_number if p.invoices.exists() else f"RCPT-{p.id:04d}"
                h_name = p.blood_request.hospital.name if p.blood_request and p.blood_request.hospital else "N/A"
                receipts.append({
                    'id': p.id,
                    'receipt_number': p.receipts.first().receipt_number if p.receipts.exists() else (p.transaction_id or inv_num),
                    'transaction_reference': p.transaction_reference or p.external_reference or p.transaction_id or "N/A",
                    'user_name': user.full_name,
                    'user_role': 'Patient',
                    'created_at': p.created_at.isoformat(),
                    'payment_type': 'Blood Request Payment',
                    'description': f"Blood Request Fulfill: {p.blood_request.quantity} Unit(s) of {p.blood_request.blood_group} blood." if p.blood_request else "Blood Request Fulfill Payment",
                    'amount': float(p.amount),
                    'payment_method': p.payment_method,
                    'status': p.status,
                    'reference_id': p.blood_request.id if p.blood_request else None,
                    'hospital_name': h_name,
                    'subscription_period': None,
                })
        elif role in ('hospital_staff', 'blood_bank_admin'):
            # Get staff hospital subscription payments
            from hospitals.models import HospitalStaff
            staff_profile = HospitalStaff.objects.filter(user=user).first()
            if staff_profile and staff_profile.hospital:
                subs = Payment.objects.filter(hospital=staff_profile.hospital, payment_type='HOSPITAL_SUBSCRIPTION')
                for s in subs:
                    inv_num = s.invoices.first().invoice_number if s.invoices.exists() else f"INV-SUB-{s.id:04d}"
                    h_name = staff_profile.hospital.name
                    sub_period = f"{max(1, int(s.amount // 25))} Month(s)" if s.payment_type == 'HOSPITAL_SUBSCRIPTION' else None
                    receipts.append({
                        'id': s.id,
                        'receipt_number': s.receipts.first().receipt_number if s.receipts.exists() else (s.transaction_id or inv_num),
                        'transaction_reference': s.transaction_reference or s.external_reference or s.transaction_id or "N/A",
                        'user_name': user.full_name,
                        'user_role': 'Hospital Staff',
                        'created_at': s.created_at.isoformat(),
                        'payment_type': 'Hospital Subscription',
                        'description': f"Hospital subscription renew: {max(1, int(s.amount // 25))} Months plan.",
                        'amount': float(s.amount),
                        'payment_method': s.payment_method,
                        'status': s.status,
                        'reference_id': inv_num,
                        'hospital_name': h_name,
                        'subscription_period': sub_period,
                    })

        # Sort receipts by date descending
        receipts.sort(key=lambda x: x['created_at'], reverse=True)
        return Response(receipts, status=status.HTTP_200_OK)


@method_decorator(csrf_exempt, name='dispatch')
class CampayWebhookView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        logger.info(f"[CampayWebhookTrace] Webhook payload received: {request.data}")
        data = request.data or {}
        ref = data.get('reference') or data.get('id') or data.get('transaction_id')
        status_raw = str(data.get('status', '')).upper()
        ext_ref = data.get('external_reference') or data.get('ext_ref')

        if not ref and not ext_ref:
            return Response({'error': 'Reference missing'}, status=status.HTTP_400_BAD_REQUEST)

        # Lookup payment record (using Campay reference or internal reference keys)
        payment = Payment.objects.filter(
            Q(transaction_reference=ref) |
            Q(external_reference=ref) |
            Q(transaction_id=ref) |
            Q(transaction_id=ext_ref) |
            Q(transaction_reference=ext_ref) |
            Q(external_reference=ext_ref)
        ).first()

        if not payment:
            logger.error(f"[CampayWebhookTrace] Campay webhook payment not found for reference: {ref}, ext_ref: {ext_ref}")
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)

        # Secure Verification: Verify status directly against Campay gateway endpoint
        ref_to_check = payment.transaction_reference or payment.external_reference or ref
        provider = get_payment_provider(payment.payment_method)
        result = provider.verify(ref_to_check)

        if result.status == 'SUCCESS' or status_raw in ('SUCCESSFUL', 'SUCCESS', 'PAID', 'COMPLETED'):
            from .services import process_successful_payment
            process_successful_payment(
                payment_id=payment.id,
                transaction_reference=ref_to_check,
                phone_number=payment.phone_number,
                payment_method=payment.payment_method,
                amount=payment.amount,
                paid_at=timezone.now(),
                response_data=result.response_data or data
            )
            logger.info(f"[CampayWebhookTrace] Campay payment {payment.transaction_id} verified successfully via webhook.")
        elif result.status == 'FAILED' or status_raw in ('FAILED', 'CANCELLED', 'DECLINED'):
            payment.status = 'FAILED'
            payment.payment_status = 'FAILED'
            payment.response_data = result.response_data or data
            payment.save()
            logger.info(f"[CampayWebhookTrace] Campay payment {payment.transaction_id} marked FAILED via webhook.")

        return Response({'status': 'acknowledged'}, status=status.HTTP_200_OK)


