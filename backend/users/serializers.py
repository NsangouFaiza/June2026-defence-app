from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Custom token serializer that includes user data and subscription status check."""

    def validate(self, attrs):
        data = super().validate(attrs)

        # Check hospital staff subscription status
        if self.user.role == 'hospital_staff':
            from hospitals.models import HospitalStaff
            try:
                staff = HospitalStaff.objects.get(user=self.user)
                hospital = staff.hospital
                if not hospital.is_subscription_active:
                    raise serializers.ValidationError({
                        'detail': 'Hospital subscription is inactive or expired. Please renew your subscription to access the application.',
                        'code': 'SUBSCRIPTION_EXPIRED',
                        'hospital_id': hospital.id,
                        'hospital_name': hospital.name,
                        'subscription_end_date': hospital.subscription_end_date.isoformat() if hospital.subscription_end_date else None,
                    })
            except HospitalStaff.DoesNotExist:
                pass

        data['user'] = {
            'id': self.user.id,
            'email': self.user.email,
            'full_name': self.user.full_name,
            'role': self.user.role,
            'blood_group': self.user.blood_group,
            'language': self.user.language,
            'profile_picture': self.user.profile_picture.url if self.user.profile_picture else None,
        }
        return data


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model."""

    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'gender', 'date_of_birth',
            'blood_group', 'phone_number', 'address', 'city', 'region',
            'role', 'notification_preferences', 'email_notifications',
            'language', 'profile_picture', 'is_verified', 'is_active',
            'date_joined',
        ]
        read_only_fields = ['id', 'is_verified', 'date_joined']


class RegisterSerializer(serializers.ModelSerializer):
    """Serializer for user registration."""

    password = serializers.CharField(write_only=True, min_length=8)
    password_confirm = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = [
            'full_name', 'email', 'phone_number', 'password', 'password_confirm',
            'gender', 'date_of_birth', 'blood_group', 'address', 'city', 'region', 'role', 'language',
        ]

    def validate(self, attrs):
        if attrs['password'] != attrs['password_confirm']:
            raise serializers.ValidationError("Passwords don't match.")
        return attrs

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        password = validated_data.pop('password')
        user = User.objects.create_user(password=password, **validated_data)
        return user


class LoginSerializer(serializers.Serializer):
    """Serializer for login."""

    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)


class ForgotPasswordSerializer(serializers.Serializer):
    """Serializer for forgot password."""

    email = serializers.EmailField()


class ChangePasswordSerializer(serializers.Serializer):
    """Serializer for changing password."""

    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=8)
