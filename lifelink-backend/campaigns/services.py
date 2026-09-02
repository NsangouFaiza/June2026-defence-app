import logging
from django.utils import timezone
from .models import Campaign

logger = logging.getLogger(__name__)

def publish_campaign_helper(campaign):
    """Helper to transition a campaign to PUBLISHED status and notify targeted donors."""
    if campaign.status == 'PUBLISHED':
        return
        
    campaign.status = 'PUBLISHED'
    campaign.save()
    
    from donors.models import Donor
    from notifications.models import Notification
    from django.db.models import Q
    from datetime import date
    
    donors = Donor.objects.all()
    if campaign.target_blood_group:
        donors = donors.filter(user__blood_group__iexact=campaign.target_blood_group)
    if campaign.target_location:
        donors = donors.filter(Q(user__city__icontains=campaign.target_location) | Q(user__region__icontains=campaign.target_location))
    if campaign.target_eligibility == 'eligible':
        donors = donors.filter(is_eligible=True)
    elif campaign.target_eligibility == 'ineligible':
        donors = donors.filter(is_eligible=False)
    
    if campaign.target_age_min:
        max_dob = date(date.today().year - campaign.target_age_min, date.today().month, date.today().day)
        donors = donors.filter(user__date_of_birth__lte=max_dob)
    if campaign.target_age_max:
        min_dob = date(date.today().year - campaign.target_age_max - 1, date.today().month, date.today().day)
        donors = donors.filter(user__date_of_birth__gte=min_dob)
        
    logger.info(f"Publishing campaign '{campaign.title}' (ID {campaign.id}) targeting {donors.count()} donors.")
    
    for donor in donors:
        # Check if already notified to avoid duplicate notifications
        if not Notification.objects.filter(recipient=donor.user, notification_type='CAMPAIGN', data__campaign_id=campaign.id).exists():
            Notification.objects.create(
                recipient=donor.user,
                notification_type='CAMPAIGN',
                title=f"New Blood Campaign: {campaign.title}",
                message=f"A new campaign '{campaign.title}' has been published. Read details and register RSVP!",
                data={'campaign_id': campaign.id, 'priority': campaign.priority}
            )
            
    campaign.is_sent = True
    campaign.recipient_count = donors.count()
    campaign.save()

def publish_scheduled_campaigns():
    """Finds and publishes scheduled campaigns whose delivery dates have arrived."""
    now = timezone.now()
    scheduled_campaigns = Campaign.objects.filter(status='SCHEDULED', scheduled_delivery__lte=now)
    count = 0
    for campaign in scheduled_campaigns:
        try:
            publish_campaign_helper(campaign)
            count += 1
        except Exception as e:
            logger.error(f"Error publishing scheduled campaign ID {campaign.id}: {e}")
    return count
