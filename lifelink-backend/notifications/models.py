from django.db import models
from django.conf import settings


NOTIFICATION_TYPE_CHOICES = (
    ('APPOINTMENT_REMINDER', 'Appointment Reminder'),
    ('ELIGIBILITY_REMINDER', 'Eligibility Reminder'),
    ('EMERGENCY_REQUEST', 'Emergency Blood Request'),
    ('CAMPAIGN', 'Campaign Announcement'),
    ('REQUEST_UPDATE', 'Request Status Update'),
    ('DONATION_COMPLETE', 'Donation Complete'),
    ('REWARD_EARNED', 'Reward Earned'),
    ('SYSTEM', 'System Notification'),
)


class Notification(models.Model):
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPE_CHOICES)
    title = models.CharField(max_length=255)
    message = models.TextField()
    data = models.JSONField(default=dict, blank=True)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['recipient', 'is_read']),
            models.Index(fields=['notification_type']),
        ]

    def __str__(self):
        return f"{self.recipient.email} - {self.title}"
