from django.db import models
from django.conf import settings
from django.utils import timezone


class Donor(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='donor_profile')
    total_donations = models.PositiveIntegerField(default=0)
    total_blood_units = models.PositiveIntegerField(default=0)
    lives_saved = models.PositiveIntegerField(default=0)
    last_donation_date = models.DateField(null=True, blank=True)
    next_eligible_date = models.DateField(null=True, blank=True)
    is_eligible = models.BooleanField(default=True)
    eligibility_reason = models.TextField(blank=True)
    points = models.PositiveIntegerField(default=0)
    level = models.CharField(max_length=50, default='Bronze')
    is_anonymous = models.BooleanField(default=False)
    is_available = models.BooleanField(default=True)
    eligibility_status = models.CharField(max_length=30, default='eligible', choices=[
        ('eligible', 'Eligible'),
        ('temporarily_ineligible', 'Temporarily Ineligible'),
        ('permanently_ineligible', 'Permanently Ineligible'),
    ])
    weight = models.FloatField(null=True, blank=True, help_text='Weight in kg')
    height = models.FloatField(null=True, blank=True, help_text='Height in cm')
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-total_donations']
        indexes = [
            models.Index(fields=['is_eligible']),
            models.Index(fields=['next_eligible_date']),
            models.Index(fields=['is_available', 'eligibility_status']),
        ]

    def __str__(self):
        return self.user.full_name

    def update_eligibility(self):
        if self.last_donation_date:
            from datetime import timedelta
            next_date = self.last_donation_date + timedelta(days=60)
            self.next_eligible_date = next_date
            self.is_eligible = timezone.now().date() >= next_date
        self.save()
