from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()


class Hospital(models.Model):
    """Hospital model."""

    name = models.CharField(max_length=200)
    address = models.TextField()
    city = models.CharField(max_length=100)
    region = models.CharField(max_length=100)
    phone_number = models.CharField(max_length=20)
    email = models.EmailField(blank=True, null=True)
    description = models.TextField(blank=True, null=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['region']),
            models.Index(fields=['city']),
        ]

    def __str__(self):
        return self.name


class HospitalStaff(models.Model):
    """Hospital Staff model linking User to Hospital."""

    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='hospital_staff')
    hospital = models.ForeignKey(Hospital, on_delete=models.CASCADE, related_name='staff')
    position = models.CharField(max_length=100, blank=True, null=True)
    department = models.CharField(max_length=100, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['user__full_name']
        unique_together = ['user', 'hospital']

    def __str__(self):
        return f"{self.user.full_name} - {self.hospital.name}"
