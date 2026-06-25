from django.db import models
from django.conf import settings


class Patient(models.Model):
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='patient_profile')
    emergency_contact_name = models.CharField(max_length=255, blank=True)
    emergency_contact_phone = models.CharField(max_length=20, blank=True)
    medical_conditions = models.TextField(blank=True)
    current_medications = models.TextField(blank=True)
    weight = models.FloatField(null=True, blank=True, help_text='Weight in kg')
    height = models.FloatField(null=True, blank=True, help_text='Height in cm')
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    medical_history = models.TextField(blank=True)
    allergies = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['user__full_name']

    def __str__(self):
        return self.user.full_name
