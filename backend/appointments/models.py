from django.db import models
from django.conf import settings


APPOINTMENT_STATUS_CHOICES = (
    ('SCHEDULED', 'Scheduled'),
    ('CONFIRMED', 'Confirmed'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
    ('NO_SHOW', 'No Show'),
)


class Appointment(models.Model):
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='appointments')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.CASCADE, related_name='appointments')
    scheduled_date = models.DateField()
    scheduled_time = models.TimeField()
    status = models.CharField(max_length=20, choices=APPOINTMENT_STATUS_CHOICES, default='SCHEDULED')
    notes = models.TextField(blank=True)
    confirmed_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='confirmed_appointments')
    completed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-scheduled_date', '-scheduled_time']
        indexes = [
            models.Index(fields=['donor', 'status']),
            models.Index(fields=['hospital', 'scheduled_date']),
        ]

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.hospital.name} ({self.scheduled_date})"
