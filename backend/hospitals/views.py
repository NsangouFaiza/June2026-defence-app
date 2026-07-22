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
        """Process monthly hospital subscription payment (25 FCFA / month)."""
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

        months = max(1, int(amount // 25))
        now = timezone.now()
        start_date = hospital.subscription_end_date if (hospital.subscription_end_date and hospital.subscription_end_date > now) else now
        end_date = start_date + timedelta(days=30 * months)

        txn_id = f"TXN-SUB-{hospital.id}-{int(now.timestamp())}"
        inv_num = f"INV-HOSP-{now.strftime('%Y%m%d')}-{uuid.uuid4().hex[:6].upper()}"

        user_obj = request.user if request.user.is_authenticated else None

        payment = HospitalSubscriptionPayment.objects.create(
            hospital=hospital,
            staff_user=user_obj,
            amount=amount,
            months=months,
            payment_method=payment_method,
            status='SUCCESS',
            transaction_id=txn_id,
            invoice_number=inv_num,
            phone_number=phone_number,
            paid_at=now,
            subscription_period_start=start_date,
            subscription_period_end=end_date,
            response_data={
                'provider': payment_method,
                'status': 'SUCCESS',
                'months_paid': months,
            }
        )

        # Extend hospital subscription
        hospital.extend_subscription(months)

        # Notifications
        # 1. Notify Staff member
        if user_obj:
            Notification.objects.create(
                recipient=user_obj,
                notification_type='HOSPITAL_SUBSCRIPTION',
                title='Hospital Subscription Payment Successful',
                message=f"Payment of {amount:,.0f} FCFA for {hospital.name} ({months} month(s)) was successful. Invoice #{inv_num}. Subscription valid until {end_date.strftime('%Y-%m-%d')}.",
                data={
                    'hospital_id': hospital.id,
                    'invoice_number': inv_num,
                    'amount': amount,
                    'months': months,
                }
            )

        # 2. Notify System Admins
        admin_users = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
        for admin in admin_users:
            Notification.objects.create(
                recipient=admin,
                notification_type='HOSPITAL_SUBSCRIPTION',
                title='Hospital Subscription Received',
                message=f"Hospital '{hospital.name}' paid {amount:,.0f} FCFA ({months} month(s)). Invoice #{inv_num}.",
                data={
                    'hospital_id': hospital.id,
                    'invoice_number': inv_num,
                    'amount': amount,
                }
            )

        # 3. Broadcast notification to ALL users (Patients, Donors, Admins)
        notify_all_users_new_hospital(hospital)

        serializer = HospitalSubscriptionPaymentSerializer(payment)
        return Response({
            'message': 'Subscription payment successful',
            'payment': serializer.data,
            'hospital': HospitalSerializer(hospital).data
        }, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'], permission_classes=[permissions.AllowAny])
    def subscription_history(self, request):
        """Get payment history and invoices for a hospital."""
        hospital_id = request.query_params.get('hospital_id')
        queryset = HospitalSubscriptionPayment.objects.all()

        if hospital_id:
            queryset = queryset.filter(hospital_id=hospital_id)
        elif request.user.is_authenticated and hasattr(request.user, 'hospital_staff'):
            queryset = queryset.filter(hospital=request.user.hospital_staff.hospital)
        elif not (request.user.is_authenticated and (request.user.role == 'system_admin' or request.user.is_staff)):
            return Response([], status=status.HTTP_200_OK)

        serializer = HospitalSubscriptionPaymentSerializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'], permission_classes=[permissions.AllowAny])
    def invoice_detail(self, request):
        """Get single invoice details by invoice_number or payment id."""
        inv_num = request.query_params.get('invoice_number')
        payment_id = request.query_params.get('id')

        try:
            if inv_num:
                payment = HospitalSubscriptionPayment.objects.get(invoice_number=inv_num)
            elif payment_id:
                payment = HospitalSubscriptionPayment.objects.get(id=payment_id)
            else:
                return Response({'error': 'invoice_number or id required'}, status=status.HTTP_400_BAD_REQUEST)
        except HospitalSubscriptionPayment.DoesNotExist:
            return Response({'error': 'Invoice not found'}, status=status.HTTP_404_NOT_FOUND)

        serializer = HospitalSubscriptionPaymentSerializer(payment)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAdminUser])
    def toggle_active(self, request, pk=None):
        """Admin toggle for hospital active/subscription access status."""
        hospital = self.get_object()
        action_type = request.data.get('action', 'toggle')

        if action_type == 'deactivate':
            hospital.is_active = False
            hospital.subscription_status = 'DEACTIVATED'
        elif action_type == 'activate':
            hospital.is_active = True
            hospital.subscription_status = 'ACTIVE'
            notify_all_users_new_hospital(hospital)
        else:
            hospital.is_active = not hospital.is_active
            hospital.subscription_status = 'ACTIVE' if hospital.is_active else 'DEACTIVATED'
            if hospital.is_active:
                notify_all_users_new_hospital(hospital)

        hospital.save(update_fields=['is_active', 'subscription_status', 'updated_at'])
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

