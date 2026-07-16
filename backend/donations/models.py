from django.db import models
from django.conf import settings


DONATION_STATUS_CHOICES = (
    ('COMPLETED', 'Completed'),
    ('CANCELLED', 'Cancelled'),
    ('REJECTED', 'Rejected'),
)


class Donation(models.Model):
    donor = models.ForeignKey('donors.Donor', on_delete=models.CASCADE, related_name='donations')
    hospital = models.ForeignKey('hospitals.Hospital', on_delete=models.CASCADE, related_name='donations')
    appointment = models.OneToOneField('appointments.Appointment', on_delete=models.SET_NULL, null=True, blank=True, related_name='donation')
    blood_group = models.CharField(max_length=3, choices=[
        ('A+', 'A+'), ('A-', 'A-'), ('B+', 'B+'), ('B-', 'B-'),
        ('AB+', 'AB+'), ('AB-', 'AB-'), ('O+', 'O+'), ('O-', 'O-'),
    ])
    quantity_ml = models.PositiveIntegerField(help_text='Quantity in milliliters')
    status = models.CharField(max_length=20, choices=DONATION_STATUS_CHOICES, default='COMPLETED')
    screened_by = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='screened_donations')
    screening_notes = models.TextField(blank=True)
    is_usable = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['donor', 'status']),
            models.Index(fields=['hospital', 'created_at']),
        ]

    def save(self, *args, **kwargs):
        is_completed_flow = (self.status == 'COMPLETED')
        
        super().save(*args, **kwargs)
        
        if is_completed_flow:
            donor = self.donor
            # Recalculate completed donations
            completed_donations = donor.donations.filter(status='COMPLETED')
            donor.total_donations = completed_donations.count()
            donor.total_blood_units = donor.total_donations
            donor.lives_saved = donor.total_donations * 3
            
            latest_donation = completed_donations.order_by('-created_at').first()
            if latest_donation:
                donor.last_donation_date = latest_donation.created_at.date()
                from datetime import timedelta
                donor.next_eligible_date = donor.last_donation_date + timedelta(days=90)
                
                from django.utils import timezone
                donor.is_eligible = timezone.now().date() >= donor.next_eligible_date
            
            donor.points = donor.total_donations * 50
            
            if donor.points >= 500:
                donor.level = 'Platinum'
            elif donor.points >= 400:
                donor.level = 'Gold'
            elif donor.points >= 250:
                donor.level = 'Silver'
            else:
                donor.level = 'Bronze'
                
            donor.save()
            
            # Award badges based on the donor's updated points
            from rewards.models import Badge, DonorReward
            eligible_badges = Badge.objects.filter(points_required__lte=donor.points)
            for badge in eligible_badges:
                DonorReward.objects.get_or_create(donor=donor, badge=badge)
                
            # Set related appointment status to COMPLETED
            if self.appointment:
                if self.appointment.status != 'COMPLETED':
                    self.appointment.status = 'COMPLETED'
                    self.appointment.save(update_fields=['status'])
                    
            # Auto-create/update the BloodInventory record of the hospital, adding 1 unit of blood.
            from inventory.models import BloodInventory
            from datetime import timedelta
            collection_date = self.created_at.date()
            expiration_date = collection_date + timedelta(days=42)
            
            inventory_record, created = BloodInventory.objects.get_or_create(
                hospital=self.hospital,
                blood_group=self.blood_group,
                collection_date=collection_date,
                defaults={
                    'quantity': 1,
                    'expiration_date': expiration_date,
                    'status': 'available',
                    'donor': donor,
                }
            )
            if not created:
                inventory_record.quantity += 1
                inventory_record.save(update_fields=['quantity'])

    def __str__(self):
        return f"{self.donor.user.full_name} - {self.blood_group} ({self.created_at.date()})"
