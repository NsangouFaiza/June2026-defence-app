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
    blood_request = models.ForeignKey('requests.BloodRequest', on_delete=models.CASCADE, related_name='payments')
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    payment_method = models.CharField(max_length=20, choices=PAYMENT_METHOD_CHOICES)
    status = models.CharField(max_length=20, choices=PAYMENT_STATUS_CHOICES, default='PENDING')
    transaction_id = models.CharField(max_length=255, unique=True)
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
        is_success_flow = (self.status == 'SUCCESS')
        super().save(*args, **kwargs)
        if is_success_flow:
            req = self.blood_request
            req.payment_status = 'PAID'
            req.payment_reference = self.transaction_id
            req.save(update_fields=['payment_status', 'payment_reference'])

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

