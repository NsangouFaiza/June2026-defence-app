from django.db.models import Q
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework_simplejwt.tokens import RefreshToken
from django.contrib.auth import get_user_model
from django.core.mail import send_mail
from django.conf import settings
from django.utils.crypto import get_random_string
from django.utils import timezone
from datetime import timedelta

from .serializers import (
    CustomTokenObtainPairSerializer,
    UserSerializer,
    RegisterSerializer,
    ForgotPasswordSerializer,
    ChangePasswordSerializer,
)

User = get_user_model()


class CustomTokenObtainPairView(TokenObtainPairView):
    """Custom token view using our serializer."""
    permission_classes = [permissions.AllowAny]
    serializer_class = CustomTokenObtainPairSerializer


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def register(request):
    """Register a new user."""
    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        user.is_verified = True
        user.save()

        hospital_data = None
        requires_payment = False

        if user.role == 'hospital_staff':
            from hospitals.models import Hospital, HospitalStaff
            h_id = request.data.get('hospital_id')
            h_name = request.data.get('hospital_name') or request.data.get('hospital_name_input')
            h_address = request.data.get('hospital_address') or user.address or 'Cameroon'
            h_city = request.data.get('hospital_city') or user.city or 'Douala'
            h_region = request.data.get('hospital_region') or user.region or 'Littoral'
            h_phone = request.data.get('hospital_phone') or user.phone_number
            h_email = request.data.get('hospital_email') or user.email

            hospital = None
            if h_id:
                try:
                    hospital = Hospital.objects.get(pk=h_id)
                except Hospital.DoesNotExist:
                    pass
            if not hospital and h_name:
                h_name_clean = h_name.strip()
                # Try exact case-insensitive match
                hospital = Hospital.objects.filter(name__iexact=h_name_clean).first()
                if not hospital:
                    # Try partial match (e.g. HGOPY or Hôpital Laquintinie)
                    hospital = Hospital.objects.filter(name__icontains=h_name_clean).first()
                if not hospital:
                    hospital = Hospital.objects.create(
                        name=h_name_clean,
                        address=h_address,
                        city=h_city,
                        region=h_region,
                        phone_number=h_phone,
                        email=h_email,
                        is_active=True,
                        subscription_status='EXPIRED',
                    )
            if not hospital:
                hospital = Hospital.objects.create(
                    name=f"{user.full_name}'s Hospital",
                    address=user.address or 'Douala',
                    city=user.city or 'Douala',
                    region=user.region or 'Littoral',
                    phone_number=user.phone_number,
                    email=user.email,
                    is_active=True,
                    subscription_status='EXPIRED',
                )

            HospitalStaff.objects.get_or_create(
                user=user,
                defaults={'hospital': hospital, 'position': request.data.get('position', 'Staff')}
            )

            requires_payment = not hospital.is_subscription_active
            hospital_data = {
                'id': hospital.id,
                'name': hospital.name,
                'subscription_active': hospital.is_subscription_active,
                'subscription_end_date': hospital.subscription_end_date.isoformat() if hospital.subscription_end_date else None,
                'subscription_status': hospital.subscription_status,
            }

        try:
            send_verification_email(user)
        except Exception:
            pass

        refresh = RefreshToken.for_user(user)
        return Response(
            {
                'message': 'User registered successfully.',
                'access': str(refresh.access_token),
                'refresh': str(refresh),
                'requires_payment': requires_payment,
                'hospital': hospital_data,
                'user': {
                    'id': user.id,
                    'email': user.email,
                    'full_name': user.full_name,
                    'role': user.role,
                    'blood_group': user.blood_group,
                    'language': user.language,
                }
            },
            status=status.HTTP_201_CREATED
        )
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def get_current_user(request):
    """Get current user information."""
    serializer = UserSerializer(request.user)
    return Response(serializer.data)


@api_view(['PATCH'])
@permission_classes([permissions.IsAuthenticated])
def update_profile(request):
    """Update user profile."""
    serializer = UserSerializer(request.user, data=request.data, partial=True, context={'request': request})
    if serializer.is_valid():
        serializer.save()
        return Response(serializer.data)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def upload_profile_picture(request):
    """Upload or update user profile picture."""
    file_obj = request.FILES.get('profile_picture') or request.FILES.get('file') or request.FILES.get('image')
    if not file_obj:
        return Response({'detail': 'No image file provided.'}, status=status.HTTP_400_BAD_REQUEST)

    user = request.user
    if user.profile_picture:
        try:
            user.profile_picture.delete(save=False)
        except Exception:
            pass
    user.profile_picture = file_obj
    user.save()
    serializer = UserSerializer(user, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['DELETE', 'POST'])
@permission_classes([permissions.IsAuthenticated])
def delete_profile_picture(request):
    """Remove user profile picture."""
    user = request.user
    if user.profile_picture:
        try:
            user.profile_picture.delete(save=False)
        except Exception:
            pass
        user.profile_picture = None
        user.save()
    serializer = UserSerializer(user, context={'request': request})
    return Response(serializer.data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def change_password(request):
    """Change user password."""
    serializer = ChangePasswordSerializer(data=request.data)
    if serializer.is_valid():
        user = request.user
        if not user.check_password(serializer.validated_data['old_password']):
            return Response(
                {'old_password': 'Wrong password.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.set_password(serializer.validated_data['new_password'])
        user.save()
        return Response({'message': 'Password changed successfully.'})
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def forgot_password(request):
    """Send password reset email."""
    serializer = ForgotPasswordSerializer(data=request.data)
    if serializer.is_valid():
        email = serializer.validated_data['email']
        try:
            user = User.objects.get(email=email)
            token = get_random_string(100)
            user.reset_password_token = token
            user.reset_password_expires = timezone.now() + timedelta(hours=1)
            user.save()

            # Send email
            reset_url = f"{settings.FRONTEND_URL}/reset-password?token={token}"
            send_mail(
                'Password Reset Request',
                f'Click the link to reset your password: {reset_url}',
                settings.DEFAULT_FROM_EMAIL,
                [email],
                fail_silently=False,
            )
            return Response({'message': 'Password reset email sent.'})
        except User.DoesNotExist:
            return Response({'message': 'If this email exists, a reset link has been sent.'})
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def reset_password(request):
    """Reset password with token."""
    token = request.data.get('token')
    new_password = request.data.get('new_password')

    if not token or not new_password:
        return Response(
            {'error': 'Token and new password are required.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        user = User.objects.get(reset_password_token=token)
        if user.reset_password_expires < timezone.now():
            return Response(
                {'error': 'Token has expired.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        user.set_password(new_password)
        user.reset_password_token = None
        user.reset_password_expires = None
        user.save()
        return Response({'message': 'Password reset successful.'})
    except User.DoesNotExist:
        return Response(
            {'error': 'Invalid token.'},
            status=status.HTTP_400_BAD_REQUEST
        )


@api_view(['POST'])
@permission_classes([permissions.IsAuthenticated])
def logout(request):
    """Logout user by blacklisting refresh token."""
    try:
        refresh_token = request.data.get('refresh')
        if refresh_token:
            token = RefreshToken(refresh_token)
            token.blacklist()
        return Response({'message': 'Logged out successfully.'})
    except Exception as e:
        return Response(
            {'error': str(e)},
            status=status.HTTP_400_BAD_REQUEST
        )


def send_verification_email(user):
    """Send email verification link."""
    token = get_random_string(100)
    user.verification_token = token
    user.save()

    verification_url = f"{settings.FRONTEND_URL}/verify-email?token={token}"
    send_mail(
        'Verify your email',
        f'Click the link to verify your email: {verification_url}',
        settings.DEFAULT_FROM_EMAIL,
        [user.email],
        fail_silently=False,
    )


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def list_donor_contacts(request):
    """List all registered donors available for contact (excluding current user)."""
    users = User.objects.filter(role='donor').exclude(id=request.user.id).order_by('full_name')
    data = []
    for u in users:
        donor_profile = getattr(u, 'donor_profile', None)
        data.append({
            'id': u.id,
            'user_id': u.id,
            'email': u.email,
            'full_name': u.full_name,
            'role': u.role,
            'blood_group': u.blood_group or 'N/A',
            'phone_number': u.phone_number or '',
            'city': u.city or '',
            'region': u.region or '',
            'profile_picture': u.profile_picture.url if u.profile_picture else None,
            'is_eligible': donor_profile.is_eligible if donor_profile else True,
            'donor_code': donor_profile.donor_code if (donor_profile and donor_profile.donor_code) else f"DON-2026-{u.id:04d}",
        })
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def list_patient_contacts(request):
    """List all patients available for contact (excluding current user)."""
    users = User.objects.filter(role='patient').exclude(id=request.user.id).order_by('full_name')
    data = []
    for u in users:
        patient_profile = getattr(u, 'patient_profile', None)
        active_requests = 0
        medical_conditions = ''
        if patient_profile:
            active_requests = patient_profile.blood_requests.filter(status__in=['PENDING', 'APPROVED', 'FULFILLED']).count()
            medical_conditions = patient_profile.medical_conditions or ''
        data.append({
            'id': u.id,
            'user_id': u.id,
            'email': u.email,
            'full_name': u.full_name,
            'role': u.role,
            'blood_group': u.blood_group or 'N/A',
            'phone_number': u.phone_number or '',
            'city': u.city or '',
            'region': u.region or '',
            'profile_picture': u.profile_picture.url if u.profile_picture else None,
            'active_requests_count': active_requests,
            'medical_conditions': medical_conditions,
        })
    return Response(data)


@api_view(['GET'])
@permission_classes([permissions.IsAuthenticated])
def list_staff_contacts(request):
    """List all staff members available for contact (excluding current user)."""
    staff_roles = ['hospital_staff', 'blood_bank_admin', 'system_admin']
    users = User.objects.filter(
        Q(role__in=staff_roles) | Q(is_staff=True) | Q(is_superuser=True)
    ).exclude(id=request.user.id).distinct().order_by('full_name')
    data = []
    for u in users:
        hospital_name = 'LifeLink Support'
        position = 'Staff'
        if hasattr(u, 'hospital_staff') and u.hospital_staff and u.hospital_staff.hospital:
            hospital_name = u.hospital_staff.hospital.name
            position = u.hospital_staff.position or 'Hospital Staff'
        elif u.role == 'blood_bank_admin':
            position = 'Blood Bank Administrator'
        elif u.role == 'system_admin' or u.is_superuser:
            position = 'System Administrator'

        data.append({
            'id': u.id,
            'user_id': u.id,
            'email': u.email,
            'full_name': u.full_name,
            'role': u.role,
            'blood_group': u.blood_group or 'N/A',
            'phone_number': u.phone_number or '',
            'city': u.city or '',
            'region': u.region or '',
            'profile_picture': u.profile_picture.url if u.profile_picture else None,
            'hospital_name': hospital_name,
            'position': position,
        })
    return Response(data)

