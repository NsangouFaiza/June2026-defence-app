from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.db import models
from django.utils.translation import gettext_lazy as _


class CustomUserManager(BaseUserManager):
    """Custom user model manager."""

    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError(_('The Email must be set'))
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save()
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('role', 'system_admin')

        if extra_fields.get('is_staff') is not True:
            raise ValueError(_('Superuser must have is_staff=True.'))
        if extra_fields.get('is_superuser') is not True:
            raise ValueError(_('Superuser must have is_superuser=True.'))

        return self.create_user(email, password, **extra_fields)


class User(AbstractUser):
    """Custom User model for LifeLink."""

    username = None  # Remove username field
    email = models.EmailField(_('email address'), unique=True)

    # Personal Information
    full_name = models.CharField(max_length=300)
    gender = models.CharField(max_length=1, choices=[('M', 'Male'), ('F', 'Female')], blank=True, null=True)
    date_of_birth = models.DateField(blank=True, null=True)
    blood_group = models.CharField(max_length=3, blank=True, null=True)
    phone_number = models.CharField(max_length=20)
    address = models.TextField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    region = models.CharField(max_length=100, blank=True, null=True)

    # Role and Permissions
    ROLE_CHOICES = [
        ('donor', 'Donor'),
        ('patient', 'Patient'),
        ('hospital_staff', 'Hospital Staff'),
        ('lab_technician', 'Laboratory Technician'),
        ('blood_bank_admin', 'Blood Bank Administrator'),
        ('system_admin', 'System Administrator'),
    ]
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='donor')

    # Preferences
    notification_preferences = models.BooleanField(default=True)
    email_notifications = models.BooleanField(default=True)
    language = models.CharField(max_length=2, default='en')
    profile_picture = models.ImageField(upload_to='profile_pictures/', blank=True, null=True)

    # Verification
    is_verified = models.BooleanField(default=False)
    verification_token = models.CharField(max_length=100, blank=True, null=True)
    reset_password_token = models.CharField(max_length=100, blank=True, null=True)
    reset_password_expires = models.DateTimeField(blank=True, null=True)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['full_name', 'phone_number']

    objects = CustomUserManager()

    def __str__(self):
        return self.full_name

    @property
    def age(self):
        if self.date_of_birth:
            from datetime import date
            today = date.today()
            return today.year - self.date_of_birth.year - (
                (today.month, today.day) < (self.date_of_birth.month, self.date_of_birth.day)
            )
        return None
