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

        super().save(*args, **kwargs)


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
    pdf_invoice = models.CharField(max_length=255, blank=True, null=True)

    def __str__(self):
        return f"Invoice {self.invoice_number} - {self.payment.amount} FCFA"


class Receipt(models.Model):
    receipt_number = models.CharField(max_length=100, unique=True)
    payment = models.ForeignKey(Payment, on_delete=models.CASCADE, related_name='receipts')
    issued_at = models.DateTimeField(auto_now_add=True)
    amount = models.DecimalField(max_digits=12, decimal_places=2)
    payer_name = models.CharField(max_length=255, blank=True)
    payment_method = models.CharField(max_length=30)
    transaction_reference = models.CharField(max_length=255, blank=True)
    pdf_receipt = models.CharField(max_length=255, blank=True, null=True)

    class Meta:
        ordering = ['-issued_at']

    def __str__(self):
        return f"Receipt {self.receipt_number} - {self.amount} FCFA"




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
    from payments.services import get_payment_provider, process_successful_payment
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
                    process_successful_payment(
                        payment_id=p.id,
                        transaction_reference=ref,
                        phone_number=p.phone_number,
                        payment_method=p.payment_method,
                        amount=p.amount,
                        paid_at=timezone.now(),
                        response_data=result.response_data
                    )
                    local_logger.info(f"[Auto-Verify] Payment {p.transaction_id} marked SUCCESS.")
                elif result.status == 'FAILED':
                    p.status = 'FAILED'
                    p.payment_status = 'FAILED'
                    p.response_data = result.response_data
                    p.save()
                    local_logger.info(f"[Auto-Verify] Payment {p.transaction_id} marked FAILED.")
            except Exception as e:
                local_logger.error(f"[Auto-Verify] Error verifying payment {p.transaction_id}: {e}")





