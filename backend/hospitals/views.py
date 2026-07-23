import uuid
from django.db.models import Count, Sum, Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from django.contrib.auth import get_user_model

from .models import Hospital, HospitalStaff
from .serializers import HospitalSerializer, HospitalStaffSerializer, HospitalSubscriptionPaymentSerializer
from payments.models import HospitalSubscriptionPayment
from notifications.models import Notification

User = get_user_model()


class HospitalViewSet(viewsets.ModelViewSet):
    """ViewSet for Hospital model."""

    queryset = Hospital.objects.all()
    serializer_class = HospitalSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['region', 'city', 'is_active', 'subscription_status', 'has_blood_bank', 'has_emergency_services']
    search_fields = ['name', 'address', 'city', 'region', 'description', 'services']

    def get_queryset(self):
        queryset = Hospital.objects.all()
        lat_param = self.request.query_params.get('lat')
        lng_param = self.request.query_params.get('lng')
        sort_param = self.request.query_params.get('sort')

        if lat_param and lng_param and sort_param == 'nearest':
            try:
                lat = float(lat_param)
                lng = float(lng_param)
                from django.db.models import F
                from django.db.models.functions import Power
                queryset = queryset.filter(latitude__isnull=False, longitude__isnull=False).annotate(
                    distance_sq=Power(F('latitude') - lat, 2) + Power(F('longitude') - lng, 2)
                ).order_by('distance_sq')
            except (ValueError, TypeError):
                pass
        return queryset

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'pay_subscription', 'subscription_history', 'invoice_detail']:
            return [permissions.AllowAny()]
        return [permissions.IsAdminUser()]

    @action(detail=False, methods=['get'])
    def my_hospital(self, request):
        """Get the hospital associated with the current user."""
        try:
            staff = HospitalStaff.objects.get(user=request.user)
            serializer = HospitalSerializer(staff.hospital)
            return Response(serializer.data)
        except HospitalStaff.DoesNotExist:
            return Response(
                {'detail': 'No hospital assigned to this user.'},
                status=status.HTTP_404_NOT_FOUND
            )

    @action(detail=False, methods=['get'])
    def statistics(self, request):
        """Get hospital statistics."""
        try:
            staff = HospitalStaff.objects.get(user=request.user)
            hospital = staff.hospital
        except HospitalStaff.DoesNotExist:
            return Response(
                {'detail': 'No hospital assigned to this user.'},
                status=status.HTTP_404_NOT_FOUND
            )

        # Auto-verify any pending payments to refresh subscription status in real time
        from payments.models import verify_pending_payments
        try:
            verify_pending_payments(hospital=hospital)
            hospital.refresh_from_db()
        except Exception:
            pass

        from inventory.models import BloodInventory
        from appointments.models import Appointment
        from requests.models import BloodRequest

        total_units = BloodInventory.objects.filter(hospital=hospital).aggregate(
            total=Sum('quantity')
        )['total'] or 0

        low_stock = BloodInventory.objects.filter(
            hospital=hospital, quantity__lt=5
        ).count()

        pending_appointments = Appointment.objects.filter(
            hospital=hospital, status='SCHEDULED'
        ).count()

        active_requests = BloodRequest.objects.filter(
            hospital=hospital, status='PENDING'
        ).count()

        return Response({
            'total_blood_units': total_units,
            'low_stock_alerts': low_stock,
            'pending_appointments': pending_appointments,
            'active_requests': active_requests,
            'subscription_status': hospital.subscription_status,
            'subscription_end_date': hospital.subscription_end_date,
            'is_subscription_active': hospital.is_subscription_active,
        })

    @action(detail=False, methods=['post'], permission_classes=[permissions.AllowAny])
    def pay_subscription(self, request):
        """Process monthly hospital subscription payment (25 FCFA / month) via Campay."""
        print("--- Complete Request Received by Django (/api/hospitals/pay_subscription/) ---", flush=True)
        print(f"User: {request.user} (ID: {request.user.id if request.user else 'Anonymous'})", flush=True)
        print(f"Payload: {request.data}", flush=True)

        hospital_id = request.data.get('hospital_id')
        amount_raw = request.data.get('amount', 25)
        payment_method = request.data.get('payment_method', 'MTN_MOMO')
        phone_number = request.data.get('phone_number', '')

        try:
            amount = float(amount_raw)
        except (ValueError, TypeError):
            return Response({'error': 'Invalid payment amount'}, status=status.HTTP_400_BAD_REQUEST)

        if amount < 25:
            return Response({'error': 'Minimum subscription payment is 25 FCFA'}, status=status.HTTP_400_BAD_REQUEST)

        hospital = None
        if hospital_id:
            try:
                hospital = Hospital.objects.get(pk=hospital_id)
            except Hospital.DoesNotExist:
                return Response({'error': 'Hospital not found'}, status=status.HTTP_404_NOT_FOUND)
        elif request.user.is_authenticated and hasattr(request.user, 'hospital_staff'):
            hospital = request.user.hospital_staff.hospital

        if not hospital:
            return Response({'error': 'Hospital identifier required'}, status=status.HTTP_400_BAD_REQUEST)

        from payments.models import Payment
        from payments.services import get_payment_provider
        from payments.serializers import PaymentSerializer

        now = timezone.now()
        txn_id = f"TXN-SUB-{hospital.id}-{int(now.timestamp())}"
        user_obj = request.user if request.user.is_authenticated else None

        payment = Payment.objects.create(
            user=user_obj or User.objects.filter(role='system_admin').first() or User.objects.filter(is_superuser=True).first(),
            hospital=hospital,
            payment_type='HOSPITAL_SUBSCRIPTION',
            amount=amount,
            payment_method=payment_method,
            status='PENDING',
            payment_status='PENDING',
            transaction_id=txn_id,
            phone_number=phone_number,
        )

        try:
            provider = get_payment_provider(payment_method)
            result = provider.initiate(payment.amount, phone_number, txn_id)
            payment.transaction_reference = result.external_reference
            payment.response_data = result.response_data
            payment.status = result.status
            payment.payment_status = result.status
            payment.save()
        except Exception as exc:
            payment.delete()
            return Response({'error': str(exc)}, status=status.HTTP_400_BAD_REQUEST)

        serializer = PaymentSerializer(payment)
        return Response({
            'message': 'Subscription payment initiated',
            'payment': serializer.data,
            'hospital': HospitalSerializer(hospital).data
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], permission_classes=[permissions.AllowAny])
    def subscription_history(self, request):
        """Get payment history and invoices for a hospital."""
        # Auto-verify pending payments first
        from payments.models import verify_pending_payments
        if request.user.is_authenticated:
            try:
                if request.user.role == 'system_admin' or request.user.is_staff:
                    verify_pending_payments()
                elif hasattr(request.user, 'hospital_staff'):
                    verify_pending_payments(hospital=request.user.hospital_staff.hospital)
            except Exception:
                pass

        hospital_id = request.query_params.get('hospital_id')
        from payments.models import Payment
        from payments.serializers import PaymentSerializer
        queryset = Payment.objects.filter(payment_type='HOSPITAL_SUBSCRIPTION')

        if hospital_id:
            queryset = queryset.filter(hospital_id=hospital_id)
        elif request.user.is_authenticated and hasattr(request.user, 'hospital_staff'):
            queryset = queryset.filter(hospital=request.user.hospital_staff.hospital)
        elif not (request.user.is_authenticated and (request.user.role == 'system_admin' or request.user.is_staff)):
            return Response([], status=status.HTTP_200_OK)

        serializer = PaymentSerializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], permission_classes=[permissions.AllowAny])
    def invoice_detail(self, request):
        """Get single invoice details by invoice_number or payment id."""
        inv_num = request.query_params.get('invoice_number')
        payment_id = request.query_params.get('id')

        from payments.models import Payment, Invoice
        from payments.serializers import PaymentSerializer

        try:
            if inv_num:
                invoice = Invoice.objects.select_related('payment__hospital').get(invoice_number=inv_num)
                payment = invoice.payment
            elif payment_id:
                payment = Payment.objects.get(id=payment_id)
            else:
                return Response({'error': 'invoice_number or id required'}, status=status.HTTP_400_BAD_REQUEST)
        except (Invoice.DoesNotExist, Payment.DoesNotExist):
            return Response({'error': 'Invoice not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = PaymentSerializer(payment)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def toggle_active(self, request, pk=None):
        """Admin toggle for hospital active/subscription access status."""
        if not (request.user.is_staff or request.user.role == 'system_admin' or request.user.is_superuser):
            return Response({'detail': 'You do not have permission to perform this action.'}, status=status.HTTP_403_FORBIDDEN)

        hospital = self.get_object()
        action_type = request.data.get('action', 'toggle')

        from payments.models import HospitalSubscription
        from django.utils import timezone
        from datetime import timedelta

        sub, _ = HospitalSubscription.objects.get_or_create(
            hospital=hospital,
            defaults={
                'start_date': timezone.now(),
                'expiration_date': timezone.now() + timedelta(days=30),
                'active_status': True
            }
        )

        if action_type == 'deactivate':
            hospital.is_active = False
            hospital.subscription_status = 'DEACTIVATED'
            sub.active_status = False
            sub.save()
        elif action_type == 'activate':
            hospital.is_active = True
            hospital.subscription_status = 'ACTIVE'
            sub.active_status = True
            if sub.expiration_date < timezone.now():
                sub.expiration_date = timezone.now() + timedelta(days=30)
            sub.save()
            hospital.subscription_end_date = sub.expiration_date
            notify_all_users_new_hospital(hospital)
        else:
            hospital.is_active = not hospital.is_active
            hospital.subscription_status = 'ACTIVE' if hospital.is_active else 'DEACTIVATED'
            sub.active_status = hospital.is_active
            if hospital.is_active:
                if sub.expiration_date < timezone.now():
                    sub.expiration_date = timezone.now() + timedelta(days=30)
                hospital.subscription_end_date = sub.expiration_date
                notify_all_users_new_hospital(hospital)
            sub.save()

        hospital.save(update_fields=['is_active', 'subscription_status', 'subscription_end_date', 'updated_at'])
        return Response({
            'message': f"Hospital '{hospital.name}' status updated.",
            'hospital': HospitalSerializer(hospital).data
        })


def notify_all_users_new_hospital(hospital):
    """Broadcast notification to all users (Patients, Donors, Admins) when a hospital subscription is activated."""
    try:
        title = f"🏥 New Hospital Joined: {hospital.name}"
        message = (
            f"Hospital '{hospital.name}' in {hospital.city or 'Cameroon'} has joined LifeLink and activated its subscription! "
            f"It is now available for blood donation and blood request services throughout the application."
        )
        all_users = User.objects.filter(is_active=True)
        notifications = [
            Notification(
                recipient=user,
                notification_type='SYSTEM',
                title=title,
                message=message,
                data={
                    'hospital_id': hospital.id,
                    'hospital_name': hospital.name,
                    'action': 'new_hospital_joined',
                }
            )
            for user in all_users
        ]
        Notification.objects.bulk_create(notifications, ignore_conflicts=True)
    except Exception as e:
        print(f"Error broadcasting new hospital notification: {e}", flush=True)


class HospitalStaffViewSet(viewsets.ModelViewSet):
    """ViewSet for HospitalStaff model."""

    queryset = HospitalStaff.objects.all()
    serializer_class = HospitalStaffSerializer
    permission_classes = [permissions.IsAdminUser]
    filterset_fields = ['hospital', 'is_active']

