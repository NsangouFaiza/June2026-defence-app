from datetime import date, timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed demo data for LifeLink (users, hospitals, inventory, campaigns)'

    def handle(self, *args, **options):
        self.stdout.write('Seeding LifeLink demo data...')

        admin, _ = User.objects.get_or_create(
            email='admin@lifelink.com',
            defaults={
                'full_name': 'System Administrator',
                'phone_number': '+237600000001',
                'role': 'system_admin',
                'is_staff': True,
                'is_superuser': True,
                'is_verified': True,
            },
        )
        if not admin.has_usable_password():
            admin.set_password('Admin@12345')
            admin.save()

        donor_user, _ = User.objects.get_or_create(
            email='donor@lifelink.com',
            defaults={
                'full_name': 'Jean Donor',
                'phone_number': '+237600000002',
                'role': 'donor',
                'blood_group': 'O+',
                'is_verified': True,
            },
        )
        if not donor_user.has_usable_password():
            donor_user.set_password('Donor@12345')
            donor_user.save()

        patient_user, _ = User.objects.get_or_create(
            email='patient@lifelink.com',
            defaults={
                'full_name': 'Marie Patient',
                'phone_number': '+237600000003',
                'role': 'patient',
                'blood_group': 'A+',
                'is_verified': True,
            },
        )
        if not patient_user.has_usable_password():
            patient_user.set_password('Patient@12345')
            patient_user.save()

        staff_user, _ = User.objects.get_or_create(
            email='staff@lifelink.com',
            defaults={
                'full_name': 'Paul Hospital Staff',
                'phone_number': '+237600000004',
                'role': 'hospital_staff',
                'is_verified': True,
            },
        )
        if not staff_user.has_usable_password():
            staff_user.set_password('Staff@12345')
            staff_user.save()

        lab_user, _ = User.objects.get_or_create(
            email='lab@lifelink.com',
            defaults={
                'full_name': 'Alice Lab Tech',
                'phone_number': '+237600000005',
                'role': 'lab_technician',
                'is_verified': True,
            },
        )
        if not lab_user.has_usable_password():
            lab_user.set_password('Lab@12345')
            lab_user.save()

        from hospitals.models import Hospital, HospitalStaff
        from blood_banks.models import BloodBank
        from donors.models import Donor
        from patients.models import Patient
        from inventory.models import BloodInventory
        from campaigns.models import Campaign
        from rewards.models import Badge

        hospital, _ = Hospital.objects.get_or_create(
            name='Central Hospital Yaoundé',
            defaults={
                'address': 'Avenue Kennedy, Yaoundé',
                'city': 'Yaoundé',
                'region': 'Centre',
                'phone_number': '+237222000000',
                'email': 'contact@central-hospital.cm',
                'latitude': 3.8480,
                'longitude': 11.5021,
                'is_active': True,
            },
        )

        HospitalStaff.objects.get_or_create(
            user=staff_user,
            hospital=hospital,
            defaults={'position': 'Inventory Manager', 'department': 'Blood Bank'},
        )

        BloodBank.objects.get_or_create(
            name='LifeLink Blood Bank Centre',
            defaults={
                'address': hospital.address,
                'city': hospital.city,
                'region': hospital.region,
                'phone_number': '+237222000001',
                'email': 'bloodbank@lifelink.com',
                'is_active': True,
            },
        )

        Donor.objects.get_or_create(
            user=donor_user,
            defaults={
                'total_donations': 3,
                'total_blood_units': 1350,
                'is_eligible': True,
                'last_donation_date': date.today() - timedelta(days=120),
            },
        )

        Patient.objects.get_or_create(
            user=patient_user,
            defaults={
                'medical_conditions': 'Scheduled surgery',
                'emergency_contact_name': 'Family Contact',
                'emergency_contact_phone': '+237600000099',
            },
        )

        today = date.today()
        for group, qty in [('O+', 12), ('A+', 8), ('B+', 5), ('AB+', 3)]:
            BloodInventory.objects.get_or_create(
                hospital=hospital,
                blood_group=group,
                collection_date=today - timedelta(days=7),
                defaults={
                    'quantity': qty,
                    'expiration_date': today + timedelta(days=35),
                    'status': 'available',
                },
            )

        Campaign.objects.get_or_create(
            title='World Blood Donor Day 2026',
            defaults={
                'description': 'Join our community blood drive and save lives.',
                'campaign_type': 'DONATION_AWARENESS',
                'status': 'PUBLISHED',
                'hospital': hospital,
                'start_date': today,
                'end_date': today + timedelta(days=14),
                'location': hospital.address,
                'organizer': admin,
            },
        )

        Badge.objects.get_or_create(
            name='BRONZE',
            defaults={
                'description': 'Completed first blood donation',
                'points_required': 100,
                'icon': 'bronze_badge',
            },
        )

        self.stdout.write(self.style.SUCCESS('Demo data seeded successfully.'))
        self.stdout.write('Demo accounts:')
        self.stdout.write('  admin@lifelink.com / Admin@12345')
        self.stdout.write('  donor@lifelink.com / Donor@12345')
        self.stdout.write('  patient@lifelink.com / Patient@12345')
        self.stdout.write('  staff@lifelink.com / Staff@12345')
        self.stdout.write('  lab@lifelink.com / Lab@12345')
