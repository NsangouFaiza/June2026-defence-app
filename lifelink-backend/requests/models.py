from django.db import models
from django.conf import settings


REQUEST_STATUS_CHOICES = (
    ('PENDING', 'Pending'),
    ('APPROVED', 'Approved'),
    ('CONFIRMED', 'Confirmed'),
    ('REJECTED', 'Rejected'),
    ('FULFILLED', 'Fulfilled'),
    ('CANCELLED', 'Cancelled'),
)

URGENCY_CHOICES = (
    ('LOW', 'Low'),
    ('MEDIUM', 'Medium'),
    ('HIGH', 'High'),
    ('CRITICAL', 'Critical'),
)


class BloodRequest(models.Model):
    patient = models.ForeignKey('patients.Patient', on_delete=models.CASCADE, related_name='blood_requests')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.SET_NULL, null=True, blank=True, related_name='blood_requests')
    blood_group = models.CharField(max_length=3, choices=[
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ])
    quantity = models.PositiveIntegerField()
    urgency = models.CharField(max_length=20, choices=URGENCY_CHOICES, default='MEDIUM')
    reason = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=REQUEST_STATUS_CHOICES, default='PENDING')
    is_emergency = models.BooleanField(default=False)
    payment_status = models.CharField(max_length=20, choices=[('PENDING', 'Pending'), ('PAID', 'Paid'), ('FAILED', 'Failed')], default='PENDING')
    payment_reference = models.CharField(max_length=255, blank=True)
    fulfillment_type = models.CharField(
        max_length=30,
        choices=(
            ('DIRECT_DONATION', 'Direct Donation'),
            ('INVENTORY', 'From Inventory'),
        ),
        blank=True,
        null=True
    )
    donor = models.ForeignKey('donors.Donor', on_delete=models.SET_NULL, null=True, blank=True, related_name='blood_requests')
    processed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='processed_requests')
    notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['patient', 'status']),
            models.Index(fields=['hospital', 'status']),
            models.Index(fields=['is_emergency']),
            models.Index(fields=['urgency']),
        ]

    def __str__(self):
        return f"{self.patient.user.full_name} - {self.blood_group} ({self.quantity})"
