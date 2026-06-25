from django.db import models
from django.conf import settings


BADGE_CHOICES = (
    ('BRONZE', 'Bronze Donor'),
    ('SILVER', 'Silver Donor'),
    ('GOLD', 'Gold Donor'),
    ('PLATINUM', 'Platinum Donor'),
    ('LIFE_SAVER', 'Life Saver'),
    ('EMERGENCY_HERO', 'Emergency Hero'),
    ('TOP_COMMUNITY', 'Top Community Donor'),
)


class Badge(models.Model):
    name = models.CharField(max_length=50, choices=BADGE_CHOICES, unique=True)
    description = models.TextField()
    icon = models.CharField(max_length=255, blank=True)
    criteria = models.JSONField(default=dict)
    points_required = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['points_required']

    def __str__(self):
        return self.get_name_display()


class DonorReward(models.Model):
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='rewards')
    badge = models.ForeignKey(Badge, on_delete=models.CASCADE, related_name='donor_rewards')
    awarded_at = models.DateTimeField(auto_now_add=True)
    awarded_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        ordering = ['-awarded_at']
        unique_together = ['donor', 'badge']

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.badge.name}"
