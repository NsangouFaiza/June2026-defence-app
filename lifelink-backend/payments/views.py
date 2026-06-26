from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets
from django.utils import timezone

from .models import Payment
from .serializers import PaymentSerializer
from .services import get_payment_provider


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
        )

        if payment_method in ('MTN_MOMO', 'ORANGE_MONEY'):
            try:
                provider = get_payment_provider(payment_method)
                result = provider.initiate(payment.amount, phone_number, transaction_id)
                payment.external_reference = result.external_reference
                payment.response_data = result.response_data
                payment.status = result.status
                payment.save()
            except ValueError as exc:
                return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PaymentSerializer(payment)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['post'])
    def verify(self, request):
        """Verify a pending Mobile Money payment (stub)."""
        payment_id = request.data.get('payment_id')
        if not payment_id:
            return Response({'error': 'payment_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payment = Payment.objects.get(pk=payment_id, user=request.user)
        except Payment.DoesNotExist:
            return Response({'error': 'Payment not found'}, status=status.HTTP_404_NOT_FOUND)

        if payment.payment_method in ('MTN_MOMO', 'ORANGE_MONEY') and payment.external_reference:
            provider = get_payment_provider(payment.payment_method)
            result = provider.verify(payment.external_reference)
            payment.status = result.status
            payment.response_data = result.response_data
            if result.status == 'SUCCESS':
                payment.paid_at = timezone.now()
            payment.save()

        serializer = PaymentSerializer(payment)
        return Response(serializer.data)
