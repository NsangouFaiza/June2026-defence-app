from django.db import models
from django.conf import settings


CAMPAIGN_TYPE_CHOICES = (
    ('DONATION_AWARENESS', 'Blood Donation Awareness'),
    ('EMERGENCY_APPEAL', 'Emergency Appeal'),
    ('HEALTH_EDUCATION', 'Health Education'),
    ('COMMUNITY_EVENT', 'Community Event'),
)

CAMPAIGN_STATUS_CHOICES = (
    ('DRAFT', 'Draft'),
    ('PUBLISHED', 'Published'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
)


class Campaign(models.Model):
    title = models.CharField(max_length=255)
    description = models.TextField()
    campaign_type = models.CharField(max_length=30, choices=CAMPAIGN_TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=CAMPAIGN_STATUS_CHOICES, default='DRAFT')
    start_date = models.DateField()
    end_date = models.DateField()
    location = models.CharField(max_length=255, blank=True)
    image = models.ImageField(upload_to='campaigns/', null=True, blank=True)
    target_audience = models.CharField(max_length=255, blank=True)
    organizer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='organized_campaigns')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.SET_NULL, null=True, blank=True, related_name='campaigns')
    participants = models.ManyToManyField('donors.Donor', related_name='campaigns', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-start_date']
        indexes = [
            models.Index(fields=['status', 'start_date']),
            models.Index(fields=['campaign_type']),
        ]

    def __str__(self):
        return self.title
