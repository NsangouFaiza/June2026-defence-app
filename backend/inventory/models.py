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
