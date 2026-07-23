from django.db import models
from django.conf import settings


PAYMENT_METHOD_CHOICES = (
    ('MTN_MOMO', 'MTN Mobile Money'),
    ('ORANGE_MONEY', 'Orange Money'),
    ('CASH', 'Cash'),
    ('CARD', 'Card'),
)

PAYMENT_STATUS_CHOICES = (
    ('PENDING', 'Pending'),
    ('SUCCESS', 'Success'),
    ('FAILED', 'Failed'),
    ('REFUNDED', 'Refunded'),
)


class Payment(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='payments')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.SET_NULL, null=True, blank=True, related_name='payments')
    payment_type = models.CharField(
        max_length=50,
        default='BLOOD_REQUEST_PAYMENT',
        choices=[
            ('HOSPITAL_SUBSCRIPTION', 'Hospital Subscription'),
            ('BLOOD_REQUEST_PAYMENT', 'Blood Request Payment')
        ]
    )
    blood_request = models.ForeignKey('requests.BloodRequest', on_delete=models.CASCADE, related_name='payments', null=True, blank=True)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES)
    status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING')
    payment_status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING')
    transaction_id = models.CharField(max_length=255, unique=True)
    transaction_reference = models.CharField(max_length=255, blank=True)
    phone_number = models.CharField(max_length=20, blank=True)
    external_reference = models.CharField(max_length=255, blank=True)
    response_data = models.JSONField(default=dict, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', 'status']),
            models.Index(fields=['transaction_id']),
        ]

    def save(self, *args, **kwargs):
        # Keep status and payment_status in sync
        if self.status == 'SUCCESS' or self.payment_status == 'SUCCESS':
            self.status = 'SUCCESS'
            self.payment_status = 'SUCCESS'
        elif self.status == 'FAILED' or self.payment_status == 'FAILED':
            self.status = 'FAILED'
            self.payment_status = 'FAILED'
        else:
            if self.status != self.payment_status:
                self.payment_status = self.status

        # Safely determine if transitioning to SUCCESS state
        old_status = None
        if self.pk:
            try:
                old_status = Payment.objects.values_list('status', flat=True).get(pk=self.pk)
            except Payment.DoesNotExist:
                pass
        
        is_transitioning_to_success = (self.status == 'SUCCESS' and old_status != 'SUCCESS')
        
        super().save(*args, **kwargs)
        
        if is_transitioning_to_success:
            from django.utils import timezone
            now = timezone.now()
            
            if self.payment_type == 'HOSPITAL_SUBSCRIPTION' and self.hospital:
                from datetime import timedelta
                months = max(1, int(self.amount // 25))
                
                # Check existing subscription expiration
                sub, created = HospitalSubscription.objects.get_or_create(
                    hospital=self.hospital,
                    defaults={
                        'start_date': now,
                        'expiration_date': now + timedelta(days=30 * months),
                        'active_status': True
                    }
                )
                if not created:
                    start_date = sub.expiration_date if sub.expiration_date > now else now
                    sub.expiration_date = start_date + timedelta(days=30 * months)
                    sub.active_status = True
                    sub.save()
                
                # Update hospital model status
                self.hospital.subscription_end_date = sub.expiration_date
                self.hospital.subscription_status = 'ACTIVE'
                self.hospital.is_active = True
                self.hospital.save(update_fields=['subscription_end_date', 'subscription_status', 'is_active'])
                
                # Create Invoice
                inv_num = f"INV-HOSP-{now.strftime('%Y%m%d')}-{(self.transaction_id or 'TXN')[:6].upper()}"
                
                invoice_html = f"""
                <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #eee; max-width: 800px; margin: auto;">
                    <div style="text-align: center; margin-bottom: 20px;">
                        <h2>LifeLink Official Subscription Invoice</h2>
                        <p>Authenticity Seal: Official LifeLink Verified Payment</p>
                    </div>
                    <hr/>
                    <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                        <tr><td><strong>Invoice Number:</strong></td><td>{inv_num}</td></tr>
                        <tr><td><strong>Hospital Name:</strong></td><td>{self.hospital.name}</td></tr>
                        <tr><td><strong>Amount Paid:</strong></td><td>{self.amount} FCFA</td></tr>
                        <tr><td><strong>Period Covered:</strong></td><td>{months} Month(s)</td></tr>
                        <tr><td><strong>Payment Method:</strong></td><td>{self.payment_method}</td></tr>
                        <tr><td><strong>Transaction Reference:</strong></td><td>{self.transaction_reference or 'N/A'}</td></tr>
                        <tr><td><strong>Payment Date:</strong></td><td>{now.strftime('%Y-%m-%d %H:%M:%S')}</td></tr>
                        <tr><td><strong>Status:</strong></td><td style="color: green; font-weight: bold;">SUCCESSFUL</td></tr>
                    </table>
                    <div style="margin-top: 40px; text-align: center; color: #888; font-size: 12px;">
                        Thank you for supporting LifeLink Healthcare Network.
                    </div>
                </div>
                """
                
                Invoice.objects.get_or_create(
                    payment=self,
                    defaults={
                        'invoice_number': inv_num,
                        'downloadable_format': invoice_html
                    }
                )

                # Send notifications
                from notifications.models import Notification
                from django.contrib.auth import get_user_model
                from django.db.models import Q
                User = get_user_model()
                
                # 1. Staff notification
                if self.user:
                    Notification.objects.create(
                        recipient=self.user,
                        notification_type='HOSPITAL_SUBSCRIPTION',
                        title='Hospital Subscription Payment Successful',
                        message=f"Payment of {self.amount:,.0f} FCFA for {self.hospital.name} ({months} month(s)) was successful. Invoice #{inv_num}. Subscription valid until {sub.expiration_date.strftime('%Y-%m-%d')}.",
                        data={
                            'hospital_id': self.hospital.id,
                            'invoice_number': inv_num,
                            'amount': float(self.amount),
                            'months': months,
                        }
                    )
                
                # 2. System Admins notification
                admin_users = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
                for admin in admin_users:
                    Notification.objects.create(
                        recipient=admin,
                        notification_type='HOSPITAL_SUBSCRIPTION',
                        title='Hospital Subscription Received',
                        message=f"Hospital '{self.hospital.name}' paid {self.amount:,.0f} FCFA ({months} month(s)). Invoice #{inv_num}.",
                        data={
                            'hospital_id': self.hospital.id,
                            'invoice_number': inv_num,
                            'amount': float(self.amount),
                        }
                    )
                
                # 3. Broadcast notification to ALL users
                try:
                    from hospitals.views import notify_all_users_new_hospital
                    notify_all_users_new_hospital(self.hospital)
                except Exception:
                    pass

                
            elif self.payment_type == 'BLOOD_REQUEST_PAYMENT' and self.blood_request:
                req = self.blood_request
                req.payment_status = 'PAID'
                req.payment_reference = self.transaction_id
                
                # If classified from inventory, set request status to CONFIRMED and deduct inventory units
                if req.fulfillment_type == 'INVENTORY':
                    req.status = 'CONFIRMED'
                    
                    # Decrement from inventory
                    from inventory.models import BloodInventory
                    from django.db.models import Sum
                    
                    total_available = BloodInventory.objects.filter(
                        hospital=req.hospital,
                        blood_group=req.blood_group,
                        status='available'
                    ).aggregate(total=Sum('quantity'))['total'] or 0
                    
                    if total_available >= req.quantity:
                        remaining_to_deduct = req.quantity
                        matching_inventories = BloodInventory.objects.filter(
                            hospital=req.hospital,
                            blood_group=req.blood_group,
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
                                
                    # Keep history / audit log
                    from audit.models import AuditLog
                    AuditLog.objects.create(
                        user=self.user,
                        action='APPROVE',
                        model_name='BloodRequest',
                        object_id=str(req.id),
                        description=f"Blood request paid and confirmed. Transaction ID: {self.transaction_id}",
                        changes={'status': 'CONFIRMED', 'payment_status': 'PAID'}
                    )
                    
                    # Send notifications to hospital staff members
                    from notifications.models import Notification
                    from django.contrib.auth import get_user_model
                    from django.db.models import Q
                    User = get_user_model()
                    staff_users = User.objects.filter(hospital_staff__hospital=req.hospital, hospital_staff__is_active=True)
                    for staff in staff_users:
                        Notification.objects.create(
                            recipient=staff,
                            notification_type='REQUEST_UPDATE',
                            title='Blood Unit Issued Payment Confirmed',
                            message=f"Blood request for {req.patient.user.full_name if req.patient else 'Unknown'} ({req.blood_group}, {req.quantity} units) has been paid and confirmed. Please proceed with preparing and issuing the blood units.",
                            data={'request_id': req.id}
                        )
                req.save()

                # Create Invoice
                inv_num = f"INV-REQ-{now.strftime('%Y%m%d')}-{(self.transaction_id or 'TXN')[:6].upper()}"
                invoice_html = f"""
                <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #eee; max-width: 800px; margin: auto;">
                    <div style="text-align: center; margin-bottom: 20px;">
                        <h2>LifeLink Official Blood Request Invoice</h2>
                        <p>Authenticity Seal: Official LifeLink Verified Payment</p>
                    </div>
                    <hr/>
                    <table style="width: 100%; border-collapse: collapse; margin-top: 20px;">
                        <tr><td><strong>Invoice Number:</strong></td><td>{inv_num}</td></tr>
                        <tr><td><strong>Patient Name:</strong></td><td>{req.patient.user.full_name if req.patient else 'Unknown'}</td></tr>
                        <tr><td><strong>Blood Group:</strong></td><td>{req.blood_group}</td></tr>
                        <tr><td><strong>Quantity:</strong></td><td>{req.quantity} Unit(s)</td></tr>
                        <tr><td><strong>Amount Paid:</strong></td><td>{self.amount} FCFA</td></tr>
                        <tr><td><strong>Payment Method:</strong></td><td>{self.payment_method}</td></tr>
                        <tr><td><strong>Transaction Reference:</strong></td><td>{self.transaction_reference or 'N/A'}</td></tr>
                        <tr><td><strong>Payment Date:</strong></td><td>{now.strftime('%Y-%m-%d %H:%M:%S')}</td></tr>
                        <tr><td><strong>Status:</strong></td><td style="color: green; font-weight: bold;">SUCCESSFUL</td></tr>
                    </table>
                    <div style="margin-top: 40px; text-align: center; color: #888; font-size: 12px;">
                        Thank you for supporting LifeLink Healthcare Network.
                    </div>
                </div>
                """
                Invoice.objects.get_or_create(
                    payment=self,
                    defaults={
                        'invoice_number': inv_num,
                        'downloadable_format': invoice_html
                    }
                )

                # Send notifications to payer (patient) and system admins
                from notifications.models import Notification
                from django.contrib.auth import get_user_model
                from django.db.models import Q
                User = get_user_model()
                
                if self.user:
                    Notification.objects.create(
                        recipient=self.user,
                        notification_type='PAYMENT',
                        title='Blood Request Payment Successful',
                        message=f"Payment of {self.amount:,.0f} FCFA for Blood Request #{req.id} was successful. Invoice #{inv_num}.",
                        data={
                            'request_id': req.id,
                            'invoice_number': inv_num,
                            'amount': float(self.amount),
                        }
                    )
                # Send patient profile notification (if different user)
                if req.patient and req.patient.user and req.patient.user != self.user:
                    Notification.objects.create(
                        recipient=req.patient.user,
                        notification_type='REQUEST_UPDATE',
                        title='Payment Confirmed',
                        message=f"Payment of {self.amount:,.0f} FCFA for your Blood Request #{req.id} has been confirmed.",
                        data={'request_id': req.id}
                    )
                # Send admin notification
                admin_users = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
                for admin in admin_users:
                    Notification.objects.create(
                        recipient=admin,
                        notification_type='PAYMENT',
                        title='Blood Request Payment Received',
                        message=f"Patient {req.patient.user.full_name if req.patient else 'Unknown'} paid {self.amount:,.0f} FCFA for Blood Request #{req.id}.",
                        data={
                            'request_id': req.id,
                            'invoice_number': inv_num,
                            'amount': float(self.amount),
                        }
                    )

    def __str__(self):
        return f"{self.user.email} - {self.amount} ({self.status})"



class HospitalSubscriptionPayment(models.Model):
    """Model tracking hospital subscription payments, invoices, and receipts."""

    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.CASCADE, related_name='subscription_payments')
    staff_user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='hospital_subscription_payments')
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    months = models.IntegerField(default=1)
    payment_method = models.CharField(max_length=30, choices=PAYMENT_METHOD_CHOICES)
    status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING')
    transaction_id = models.CharField(max_length=255, unique=True)
    invoice_number = models.CharField(max_length=100, unique=True)
    phone_number = models.CharField(max_length=20, blank=True)
    external_reference = models.CharField(max_length=255, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    subscription_period_start = models.DateTimeField(null=True, blank=True)
    subscription_period_end = models.DateTimeField(null=True, blank=True)
    response_data = models.JSONField(default=dict, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['hospital', 'status']),
            models.Index(fields=['invoice_number']),
            models.Index(fields=['transaction_id']),
        ]

    def __str__(self):
        return f"Invoice {self.invoice_number} - {self.hospital.name} ({self.amount} FCFA)"


class HospitalSubscription(models.Model):
    hospital = models.OneToOneField('hospitals.Hospital', on_delete=models.CASCADE, related_name='subscription')
    start_date = models.DateTimeField()
    expiration_date = models.DateTimeField()
    active_status = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.hospital.name} Subscription - Active: {self.active_status}"


class Invoice(models.Model):
    invoice_number = models.CharField(max_length=100, unique=True)
    payment = models.ForeignKey(Payment, on_delete=models.CASCADE, related_name='invoices')
    generated_date = models.DateTimeField(auto_now_add=True)
    downloadable_format = models.TextField(blank=True, default='')

    def __str__(self):
        return f"Invoice {self.invoice_number} - {self.payment.amount} FCFA"


def check_and_update_subscriptions():
    """Dynamically checks for expired hospital subscriptions, deactivates them, and notifies admins."""
    from django.utils import timezone
    from django.contrib.auth import get_user_model
    from django.db.models import Q
    from notifications.models import Notification
    from payments.models import HospitalSubscription

    User = get_user_model()
    now = timezone.now()

    # Active subscriptions that have expired
    expired_subs = HospitalSubscription.objects.filter(active_status=True, expiration_date__lt=now)
    for sub in expired_subs:
        sub.active_status = False
        sub.save()

        # Deactivate hospital status
        hospital = sub.hospital
        hospital.subscription_status = 'EXPIRED'
        hospital.is_active = False # Block staff access
        hospital.save(update_fields=['subscription_status', 'is_active'])

        # Notify admins
        admins = User.objects.filter(Q(role='system_admin') | Q(is_superuser=True))
        for admin in admins:
            Notification.objects.get_or_create(
                recipient=admin,
                notification_type='HOSPITAL_SUBSCRIPTION',
                title='Hospital Subscription Expired',
                message=f"The subscription for '{hospital.name}' expired on {sub.expiration_date.strftime('%Y-%m-%d')}.",
                data={'hospital_id': hospital.id}
            )


def verify_pending_payments(user=None, hospital=None):
    """Automatically verifies all pending mobile money payments with Campay to ensure database is in sync."""
    from payments.models import Payment
    from payments.services import get_payment_provider
    from django.utils import timezone
    from django.db.models import Q
    import logging

    local_logger = logging.getLogger(__name__)

    # Fetch pending payments that use MTN or Orange Money and have references
    q = Q(status='PENDING') & (Q(payment_method='MTN_MOMO') | Q(payment_method='ORANGE_MONEY'))
    if user:
        q &= Q(user=user)
    if hospital:
        q &= Q(hospital=hospital)

    pending_payments = Payment.objects.filter(q)
    for p in pending_payments:
        ref = p.transaction_reference or p.external_reference or p.transaction_id
        if ref:
            try:
                provider = get_payment_provider(p.payment_method)
                result = provider.verify(ref)
                if result.status == 'SUCCESS':
                    p.status = 'SUCCESS'
                    p.payment_status = 'SUCCESS'
                    p.paid_at = timezone.now()
                    p.response_data = result.response_data
                    p.save()
                    local_logger.info(f"[Auto-Verify] Payment {p.transaction_id} marked SUCCESS.")
                elif result.status == 'FAILED':
                    p.status = 'FAILED'
                    p.payment_status = 'FAILED'
                    p.response_data = result.response_data
                    p.save()
                    local_logger.info(f"[Auto-Verify] Payment {p.transaction_id} marked FAILED.")
            except Exception as e:
                local_logger.error(f"[Auto-Verify] Error verifying payment {p.transaction_id}: {e}")




