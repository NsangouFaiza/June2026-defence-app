from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from .models import User


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Custom token serializer that includes user data and subscription status check."""

    def validate(self, attrs):
        data = super().validate(attrs)

        # Check hospital staff subscription status
        if self.user.role == 'hospital_staff':
            from payments.models import check_and_update_subscriptions, verify_pending_payments
            try:
                from hospitals.models import HospitalStaff
                staff = HospitalStaff.objects.filter(user=self.user).first()
                if staff and staff.hospital:
                    verify_pending_payments(hospital=staff.hospital)
                check_and_update_subscriptions()
            except Exception:
                pass
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

        profile_pic = None
        if hasattr(self.user, 'profile_picture') and self.user.profile_picture:
            try:
                profile_pic = self.user.profile_picture.url
            except Exception:
                profile_pic = None

        data['user'] = {
            'id': self.user.id,
            'email': self.user.email,
            'full_name': self.user.full_name,
            'role': self.user.role,
            'blood_group': self.user.blood_group,
            'language': self.user.language,
            'profile_picture': profile_pic,
        }
        return data



class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model."""

    donor_level = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'email', 'full_name', 'gender', 'date_of_birth',
            'blood_group', 'phone_number', 'address', 'city', 'region',
            'role', 'notification_preferences', 'email_notifications',
            'language', 'profile_picture', 'is_verified', 'is_active',
            'date_joined', 'donor_level',
        ]
        read_only_fields = ['id', 'is_verified', 'date_joined']

    def get_donor_level(self, obj):
        if obj.role == 'donor' and hasattr(obj, 'donor_profile'):
            return obj.donor_profile.level
        return None


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

    current_password = serializers.CharField(write_only=True, required=False)
    old_password = serializers.CharField(write_only=True, required=False)
    new_password = serializers.CharField(write_only=True, min_length=8)

    def validate(self, attrs):
        cur_pass = attrs.get('current_password') or attrs.get('old_password')
        if not cur_pass:
            raise serializers.ValidationError({'current_password': 'Current password is required.'})
        
        new_pass = attrs.get('new_password')
        if new_pass:
            import re
            if len(new_pass) < 8:
                raise serializers.ValidationError({'new_password': 'Password must be at least 8 characters long.'})
            if not re.search(r'[A-Z]', new_pass):
                raise serializers.ValidationError({'new_password': 'Password must contain at least one uppercase letter.'})
            if not re.search(r'[a-z]', new_pass):
                raise serializers.ValidationError({'new_password': 'Password must contain at least one lowercase letter.'})
            if not re.search(r'[0-9]', new_pass):
                raise serializers.ValidationError({'new_password': 'Password must contain at least one number.'})
            if not re.search(r'[!@#$%^&*(),.?":{}|<>]', new_pass):
                raise serializers.ValidationError({'new_password': 'Password must contain at least one special character.'})
        
        attrs['current_password_resolved'] = cur_pass
        return attrs


from .models import UserSession, LoginHistory

class UserSessionSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSession
        fields = ['id', 'device_name', 'ip_address', 'last_activity', 'created_at', 'is_trusted']


class LoginHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = LoginHistory
        fields = ['id', 'ip_address', 'device_name', 'login_time', 'status']


class SecuritySettingsSerializer(serializers.ModelSerializer):
    active_sessions = UserSessionSerializer(many=True, source='sessions', read_only=True)
    login_history = serializers.SerializerMethodField()
    security_score = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'two_factor_enabled',
            'biometric_enabled',
            'login_notifications_enabled',
            'recovery_email',
            'security_question',
            'security_answer',
            'active_sessions',
            'login_history',
            'security_score',
        ]
        read_only_fields = ['active_sessions', 'login_history', 'security_score']
        extra_kwargs = {
            'security_answer': {'write_only': True}
        }

    def get_login_history(self, obj):
        # Return recent 10 login history logs
        logs = obj.login_history.all().order_by('-login_time')[:10]
        return LoginHistorySerializer(logs, many=True).data

    def get_security_score(self, obj):
        score = 30  # Base score
        if obj.two_factor_enabled:
            score += 30
        if obj.biometric_enabled:
            score += 15
        if obj.recovery_email:
            score += 15
        if obj.security_question and obj.security_answer:
            score += 10
        return score
