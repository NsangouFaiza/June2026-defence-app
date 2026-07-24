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
    ('SCHEDULED', 'Scheduled'),
    ('PUBLISHED', 'Published'),
    ('ONGOING', 'Ongoing'),
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
    ('ARCHIVED', 'Archived'),
    ('EXPIRED', 'Expired'),
)


class Campaign(models.Model):
    title = models.CharField(max_length=255)
    subtitle = models.CharField(max_length=255, blank=True, null=True)
    description = models.TextField()
    campaign_type = models.CharField(max_length=30, choices=CAMPAIGN_TYPE_CHOICES)
    status = models.CharField(max_length=20, choices=CAMPAIGN_STATUS_CHOICES, default='DRAFT')
    category = models.CharField(max_length=50, default='Blood Donation')
    
    start_date = models.DateField()
    end_date = models.DateField()
    registration_deadline = models.DateField(blank=True, null=True)
    event_start_time = models.TimeField(blank=True, null=True)
    event_end_time = models.TimeField(blank=True, null=True)
    
    location = models.CharField(max_length=255, blank=True)
    latitude = models.FloatField(blank=True, null=True)
    longitude = models.FloatField(blank=True, null=True)
    city = models.CharField(max_length=100, blank=True, null=True)
    region = models.CharField(max_length=100, blank=True, null=True)
    target_radius = models.FloatField(blank=True, null=True)
    
    image = models.ImageField(upload_to='campaigns/', null=True, blank=True)
    expected_donors = models.IntegerField(blank=True, null=True)
    target_audience = models.CharField(max_length=255, blank=True)
    organizer = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='organized_campaigns')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.SET_NULL, null=True, blank=True, related_name='campaigns')
    participants = models.ManyToManyField('donors.Donor', related_name='campaigns', blank=True)
    
    priority = models.CharField(max_length=20, default='Normal', choices=[('Normal', 'Normal'), ('Urgent', 'Urgent'), ('Emergency', 'Emergency')])
    target_blood_group = models.CharField(max_length=50, blank=True, null=True)
    target_blood_groups = models.CharField(max_length=255, blank=True, null=True) # Comma-separated like "A+,O+,B-"
    target_location = models.CharField(max_length=100, blank=True, null=True)
    target_eligibility = models.CharField(max_length=50, blank=True, null=True)
    target_age_min = models.IntegerField(blank=True, null=True)
    target_age_max = models.IntegerField(blank=True, null=True)
    gender_restriction = models.CharField(max_length=20, default='None')
    
    contact_info = models.CharField(max_length=255, blank=True, null=True)
    organizer_notes = models.TextField(blank=True, null=True)
    participation_instructions = models.TextField(blank=True, null=True)
    benefits_rewards = models.TextField(blank=True, null=True)
    required_documents = models.CharField(max_length=255, blank=True, null=True)
    hashtags = models.CharField(max_length=255, blank=True, null=True)
    visibility_settings = models.CharField(max_length=30, default='Public')
    
    scheduled_delivery = models.DateTimeField(blank=True, null=True)
    is_sent = models.BooleanField(default=False)
    recipient_count = models.IntegerField(default=0)
    views_count = models.IntegerField(default=0)
    
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


class CampaignRegistration(models.Model):
    campaign = models.ForeignKey(Campaign, on_delete=models.CASCADE, related_name='registrations')
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='campaign_registrations')
    status = models.CharField(
        max_length=20,
        choices=[
            ('REGISTERED', 'Registered'),
            ('APPROVED', 'Approved'),
            ('REJECTED', 'Rejected'),
            ('CANCELLED', 'Cancelled'),
            ('ATTENDED', 'Attended')
        ],
        default='REGISTERED'
    )
    donated = models.BooleanField(default=False)
    registered_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('campaign', 'donor')

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.campaign.title} ({self.status})"
