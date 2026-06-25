from django.db import models
from django.conf import settings


ELIGIBILITY_STATUS_CHOICES = (
    ('ELIGIBLE', 'Eligible'),
    ('TEMP_INELIGIBLE', 'Temporarily Ineligible'),
    ('PERM_INELIGIBLE', 'Permanently Ineligible'),
)


class EligibilityCheck(models.Model):
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='eligibility_checks')
    checked_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='eligibility_checks')
    status = models.CharField(max_length=20, choices=ELIGIBILITY_STATUS_CHOICES)
    age_ok = models.BooleanField()
    weight_ok = models.BooleanField()
    medical_history_ok = models.BooleanField()
    recent_surgeries_ok = models.BooleanField()
    pregnancy_status_ok = models.BooleanField()
    infectious_diseases_ok = models.BooleanField()
    medication_use_ok = models.BooleanField()
    reason = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['donor', 'created_at']),
        ]

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.status} ({self.created_at.date()})"
