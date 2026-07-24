from django.db.models import Count, Sum, Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta
from django.shortcuts import get_object_or_404
from django.http import HttpResponse

from .models import Donor, DonorHealthRecord
from .serializers import DonorSerializer, DonorDetailSerializer, DonorHealthRecordSerializer


class DonorViewSet(viewsets.ModelViewSet):
    """ViewSet for Donor model."""

    queryset = Donor.objects.all()
    serializer_class = DonorSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['is_available', 'eligibility_status']
    search_fields = ['user__first_name', 'user__last_name', 'user__email']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return DonorDetailSerializer
        return DonorSerializer

    @action(detail=False, methods=['get'])
    def eligible(self, request):
        """Get eligible donors."""
        queryset = Donor.objects.filter(
            is_available=True,
            eligibility_status='eligible',
            user__is_active=True,
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def by_blood_group(self, request):
        """Get donors by blood group."""
        blood_group = request.query_params.get('blood_group')
        if not blood_group:
            return Response(
                {'error': 'blood_group parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = Donor.objects.filter(
            user__blood_group=blood_group,
            is_available=True,
            eligibility_status='eligible',
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get nearby donors (requires lat/lng)."""
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        radius = request.query_params.get('radius', 50)  # km

        if not lat or not lng:
            return Response(
                {'error': 'lat and lng parameters are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = Donor.objects.filter(
            is_available=True,
            eligibility_status='eligible',
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_profile(self, request):
        """Get current user's donor profile."""
        try:
            donor = Donor.objects.get(user=request.user)
            
            # Dynamically check and update eligibility and dispatch reminders
            if donor.last_donation_date:
                today = timezone.now().date()
                next_eligible = donor.last_donation_date + timedelta(days=90)
                if not donor.is_eligible and today >= next_eligible:
                    donor.is_eligible = True
                    donor.eligibility_status = 'eligible'
                    donor.eligibility_reason = ''
                    donor.next_eligible_date = next_eligible
                    donor.save()
                    
                    # Create notification if not already sent since this last donation
                    from notifications.models import Notification
                    notification_exists = Notification.objects.filter(
                        recipient=request.user,
                        notification_type='ELIGIBILITY_REMINDER',
                        created_at__date__gte=donor.last_donation_date
                    ).exists()
                    
                    if not notification_exists:
                        Notification.objects.create(
                            recipient=request.user,
                            notification_type='ELIGIBILITY_REMINDER',
                            title='Eligible to Donate Again! / Éligible pour donner à nouveau !',
                            message='Congratulations! 90 days have passed since your last validated blood donation. You are now eligible to donate blood again and save more lives. / Félicitations ! 90 jours se sont écoulés depuis votre premier don de sang validé. Vous êtes maintenant éligible pour donner à nouveau du sang et sauver plus de vies.',
                        )
            
            serializer = DonorDetailSerializer(donor)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response(
                {'error': 'Donor profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=['post'])
    def update_eligibility(self, request, pk=None):
        """Update donor eligibility status."""
        donor = self.get_object()
        status_value = request.data.get('status')
        reason_value = request.data.get('reason', '').strip()

        if status_value not in ['eligible', 'temporarily_ineligible', 'permanently_ineligible']:
            return Response(
                {'error': 'Invalid status. Must be eligible, temporarily_ineligible, or permanently_ineligible.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Systemic checks when trying to make a donor eligible
        if status_value == 'eligible':
            today = timezone.now().date()

            # 1. Last donation date check (within 90 days)
            if donor.last_donation_date and (today - donor.last_donation_date).days < 90:
                days_left = 90 - (today - donor.last_donation_date).days
                return Response(
                    {'error': f'Cannot make donor eligible. Last donation was within 90 days. Must wait {days_left} more days.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # 2. Age check (must be >= 18)
            if donor.user.date_of_birth:
                age = (today - donor.user.date_of_birth).days // 365
                if age < 18:
                    return Response(
                        {'error': f'Cannot make donor eligible. Donor is underage (age: {age}). Minimum age is 18.'},
                        status=status.HTTP_400_BAD_REQUEST,
                    )

            # 3. Surgery, Age, or Last Donation keywords in existing reason
            reason_lower = donor.eligibility_reason.lower()
            if 'surgery' in reason_lower:
                return Response(
                    {'error': f'Cannot make donor eligible due to systemic constraint: {donor.eligibility_reason}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if 'age' in reason_lower:
                return Response(
                    {'error': f'Cannot make donor eligible due to systemic age constraint: {donor.eligibility_reason}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if 'last donation' in reason_lower or 'recent donation' in reason_lower:
                return Response(
                    {'error': f'Cannot make donor eligible due to systemic donation interval: {donor.eligibility_reason}'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Clear reason and set eligible
            donor.is_eligible = True
            donor.eligibility_status = 'eligible'
            donor.eligibility_reason = ''
        else:
            # Setting to ineligible
            donor.is_eligible = False
            donor.eligibility_status = status_value
            donor.eligibility_reason = reason_value if reason_value else 'Manually set by staff'

        donor.save()
        serializer = self.get_serializer(donor)
        return Response(serializer.data)


class DonorHealthRecordViewSet(viewsets.ModelViewSet):
    """ViewSet for DonorHealthRecord model."""

    queryset = DonorHealthRecord.objects.all()
    serializer_class = DonorHealthRecordSerializer
    permission_classes = [permissions.IsAuthenticated]

    def perform_create(self, serializer):
        donor, _ = Donor.objects.get_or_create(user=self.request.user)
        serializer.save(donor=donor)

    @action(detail=False, methods=['get'])
    def my_records(self, request):
        """Get current donor's health records."""
        try:
            donor = Donor.objects.get(user=request.user)
            records = DonorHealthRecord.objects.filter(donor=donor)
            serializer = self.get_serializer(records, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response([])


def verify_badge_view(request, donor_code):
    """Public view to verify digital donor badge validity."""
    try:
        # Code format: DON-2026-XXXX where XXXX is 4-digit ID
        parts = donor_code.split('-')
        donor_id = int(parts[-1])
        donor = get_object_or_404(Donor, id=donor_id)
    except Exception:
        return HttpResponse("<h1>Invalid Donor Code</h1>", status=400)

    badge_level = donor.level
    badge_emoji = '🥉'
    if badge_level == 'Platinum':
        badge_emoji = '💎'
    elif badge_level == 'Gold':
        badge_emoji = '🥇'
    elif badge_level == 'Silver':
        badge_emoji = '🥈'

    is_valid = donor.user.is_active and donor.total_donations > 0

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>LifeLink Donor Badge Verification</title>
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;600;800&display=swap" rel="stylesheet">
        <style>
            body {{
                font-family: 'Outfit', sans-serif;
                background-color: #F5F7FA;
                margin: 0;
                padding: 0;
                display: flex;
                align-items: center;
                justify-content: center;
                min-height: 100vh;
            }}
            .card {{
                background-color: white;
                border-radius: 24px;
                box-shadow: 0 12px 40px rgba(0, 0, 0, 0.06);
                padding: 35px;
                width: 90%;
                max-width: 420px;
                text-align: center;
                border: 1px solid #E9ECEF;
            }}
            .logo {{
                font-size: 26px;
                font-weight: 800;
                color: #E53935;
                margin-bottom: 24px;
                letter-spacing: 0.5px;
            }}
            .badge-container {{
                font-size: 80px;
                margin: 25px 0;
                filter: drop-shadow(0 8px 16px rgba(0,0,0,0.1));
            }}
            .status-box {{
                display: inline-block;
                padding: 10px 20px;
                border-radius: 50px;
                font-weight: 700;
                font-size: 13px;
                letter-spacing: 0.8px;
                margin-bottom: 25px;
            }}
            .valid {{
                background-color: #E8F5E9;
                color: #2E7D32;
                border: 1px solid #C8E6C9;
            }}
            .invalid {{
                background-color: #FFEBEE;
                color: #C62828;
                border: 1px solid #FFCDD2;
            }}
            .name {{
                font-size: 24px;
                font-weight: 700;
                color: #212529;
                margin-bottom: 6px;
            }}
            .id-code {{
                font-size: 15px;
                color: #6C757D;
                margin-bottom: 30px;
                font-weight: 500;
            }}
            .info-grid {{
                display: grid;
                grid-template-columns: 1fr 1fr;
                gap: 20px;
                border-top: 1px solid #F1F3F5;
                padding-top: 25px;
                text-align: left;
            }}
            .info-label {{
                font-size: 11px;
                color: #868E96;
                text-transform: uppercase;
                letter-spacing: 0.6px;
                margin-bottom: 5px;
            }}
            .info-value {{
                font-size: 16px;
                color: #343A40;
                font-weight: 600;
            }}
            .footer {{
                font-size: 12px;
                color: #ADB5BD;
                margin-top: 35px;
                border-top: 1px solid #F1F3F5;
                padding-top: 20px;
            }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="logo">🔴 LifeLink</div>
            <div class="status-box {"valid" if is_valid else "invalid"}">
                {"&checkmark; VERIFIED LIFELINK DONOR" if is_valid else "&cross; INVALID / NO DONATIONS LOGGED"}
            </div>
            <div class="badge-container">
                {badge_emoji}
            </div>
            <div class="name">{donor.user.full_name}</div>
            <div class="id-code">{donor.donor_code}</div>
            
            <div class="info-grid">
                <div>
                    <div class="info-label">Blood Group</div>
                    <div class="info-value">{donor.user.blood_group or "Not Specified"}</div>
                </div>
                <div>
                    <div class="info-label">Badge Level</div>
                    <div class="info-value">{badge_level} Donor</div>
                </div>
                <div>
                    <div class="info-label">Total Donations</div>
                    <div class="info-value">{donor.total_donations}</div>
                </div>
                <div>
                    <div class="info-label">Verification Date</div>
                    <div class="info-value">{timezone.now().strftime('%Y-%m-%d')}</div>
                </div>
            </div>
            <div class="footer">
                Secured by LifeLink Verification System<br>
                Checked at: {timezone.now().strftime('%H:%M:%S UTC')}
            </div>
        </div>
    </body>
    </html>
    """
    return HttpResponse(html_content)

