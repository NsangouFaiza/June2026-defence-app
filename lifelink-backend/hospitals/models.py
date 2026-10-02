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
    opening_hours = models.CharField(max_length=150, default='24/7 Emergency & Blood Bank')
    has_blood_bank = models.BooleanField(default=True)
    has_emergency_services = models.BooleanField(default=True)
    services = models.TextField(blank=True, default='Blood Bank, Emergency Care, Transfusion, ICU, Lab Testing')
    is_active = models.BooleanField(default=True)
    subscription_end_date = models.DateTimeField(null=True, blank=True)
    SUBSCRIPTION_STATUS_CHOICES = (
        ('ACTIVE', 'Active'),
        ('EXPIRED', 'Expired'),
        ('DEACTIVATED', 'Deactivated'),
    )
    subscription_status = models.CharField(max_length=20, choices=SUBSCRIPTION_STATUS_CHOICES, default='EXPIRED')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['name']
        indexes = [
            models.Index(fields=['region']),
            models.Index(fields=['city']),
            models.Index(fields=['subscription_status']),
        ]

    def __str__(self):
        return self.name

    @property
    def is_subscription_active(self):
        if not self.is_active:
            return False
        if self.subscription_status == 'DEACTIVATED':
            return False
        if not self.subscription_end_date:
            return False
        from django.utils import timezone
        return self.subscription_end_date >= timezone.now()

    def extend_subscription(self, months: int = 1, payment_date=None):
        """Extend subscription end date by given number of calendar months."""
        from django.utils import timezone
        now = timezone.now()
        base_date = payment_date or now
        if self.is_subscription_active and self.subscription_status == 'ACTIVE' and self.subscription_end_date and self.subscription_end_date > now:
            if self.subscription_end_date <= now + timezone.timedelta(days=366):
                base_date = self.subscription_end_date

        try:
            from dateutil.relativedelta import relativedelta
            new_end = base_date + relativedelta(months=months)
        except ImportError:
            import calendar
            month = base_date.month - 1 + months
            year = base_date.year + month // 12
            month = month % 12 + 1
            day = min(base_date.day, calendar.monthrange(year, month)[1])
            new_end = base_date.replace(year=year, month=month, day=day)

        self.subscription_end_date = new_end
        self.subscription_status = 'ACTIVE'
        self.is_active = True
        self.save(update_fields=['subscription_end_date', 'subscription_status', 'is_active', 'updated_at'])
        return self.subscription_end_date




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
