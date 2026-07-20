from django.db import models
from django.utils.translation import gettext_lazy as _


class BloodInventory(models.Model):
    """Blood Inventory model."""

    STATUS_CHOICES = [
        ('available', 'Available'),
        ('reserved', 'Reserved'),
        ('used', 'Used'),
        ('expired', 'Expired'),
        ('rejected', 'Rejected'),
    ]

    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.CASCADE, related_name='inventory')
    blood_group = models.CharField(max_length=3)
    quantity = models.IntegerField(default=0)
    collection_date = models.DateField()
    expiration_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='available')
    donor = models.ForeignKey('donors.Donor', on_delete=models.SET_NULL, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['hospital', 'blood_group', 'status']),
            models.Index(fields=['expiration_date']),
        ]
        unique_together = ['hospital', 'blood_group', 'collection_date']

    def __str__(self):
        return f"{self.hospital.name} - {self.blood_group} ({self.quantity})"

    @property
    def is_expired(self):
        from django.utils import timezone
        return self.expiration_date < timezone.now().date()

    @property
    def days_until_expiry(self):
        from django.utils import timezone
        return (self.expiration_date - timezone.now().date()).days


from django.conf import settings
from django.utils import timezone


class LabTestRecord(models.Model):
    """Laboratory test & screening record model."""

    UNIT_STATUS_CHOICES = [
        ('PENDING', 'Pending Screening'),
        ('APPROVED', 'Approved / Safe'),
        ('REJECTED', 'Rejected'),
        ('QUARANTINED', 'Quarantined'),
    ]

    TEST_RESULT_CHOICES = [
        ('NEGATIVE', 'Negative (Passed)'),
        ('POSITIVE', 'Positive (Failed)'),
        ('PENDING', 'Pending Test'),
    ]

    donor = models.ForeignKey('donors.Donor', on_delete=models.SET_NULL, null=True, blank=True, related_name='lab_records')
    inventory_unit = models.ForeignKey(BloodInventory, on_delete=models.SET_NULL, null=True, blank=True, related_name='lab_records')
    sample_code = models.CharField(max_length=50, unique=True, blank=True)
    blood_group = models.CharField(max_length=3, choices=[
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ], default='O+')
    rh_factor = models.CharField(max_length=10, choices=[('POSITIVE', 'Rh+'), ('NEGATIVE', 'Rh-')], default='POSITIVE')

    # Screening parameters
    hiv_status = models.CharField(max_length=15, choices=TEST_RESULT_CHOICES, default='NEGATIVE')
    hep_b_status = models.CharField(max_length=15, choices=TEST_RESULT_CHOICES, default='NEGATIVE')
    hep_c_status = models.CharField(max_length=15, choices=TEST_RESULT_CHOICES, default='NEGATIVE')
    syphilis_status = models.CharField(max_length=15, choices=TEST_RESULT_CHOICES, default='NEGATIVE')
    malaria_status = models.CharField(max_length=15, choices=TEST_RESULT_CHOICES, default='NEGATIVE')
    hemoglobin_g_dl = models.FloatField(default=14.0, help_text='Hemoglobin in g/dL')

    unit_status = models.CharField(max_length=20, choices=UNIT_STATUS_CHOICES, default='PENDING')
    abnormal_findings = models.TextField(blank=True)
    has_abnormal_findings = models.BooleanField(default=False)

    tested_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='conducted_lab_tests')
    tested_at = models.DateTimeField(default=timezone.now)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-tested_at']

    def save(self, *args, **kwargs):
        if not self.sample_code:
            import uuid
            self.sample_code = f"LAB-{uuid.uuid4().hex[:8].upper()}"
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.sample_code} ({self.blood_group} {self.rh_factor}) - {self.unit_status}"

