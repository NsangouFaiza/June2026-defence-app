from django.db import models
from django.conf import settings


DONATION_STATUS_CHOICES = (
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
    ('REJECTED', 'Rejected'),
)


class Donation(models.Model):
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='donations')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.CASCADE, related_name='donations')
    appointment = models.OneToOneField('appointments.Appointment', on_delete=models.SET_NULL, null=True, blank=True, related_name='donation')
    blood_group = models.CharField(max_length=3, choices=[
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ])
    quantity_ml = models.PositiveIntegerField(help_text='Quantity in milliliters')
    status = models.CharField(max_length=20, choices=DONATION_STATUS_CHOICES, default='COMPLETED')
    screened_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='screened_donations')
    screening_notes = models.TextField(blank=True)
    is_usable = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['donor', 'status']),
            models.Index(fields=['hospital', 'created_at']),
        ]

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.blood_group} ({self.created_at.date()})"
