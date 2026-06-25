from rest_framework import serializers
from .models import Patient


class PatientSerializer(serializers.ModelSerializer):
    """Serializer for Patient model."""

    user = serializers.SerializerMethodField()
    active_requests_count = serializers.SerializerMethodField()

    class Meta:
        model = Patient
        fields = [
            'id', 'user',
            'weight', 'height', 'medical_history', 'allergies',
            'emergency_contact_name', 'emergency_contact_phone',
            'medical_conditions', 'current_medications',
            'latitude', 'longitude',
            'active_requests_count',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_user(self, obj):
        from users.serializers import UserSerializer
        return UserSerializer(obj.user).data

    def get_active_requests_count(self, obj):
        return obj.blood_requests.filter(
            status__in=['PENDING', 'APPROVED', 'FULFILLED']
        ).count()


class PatientDetailSerializer(PatientSerializer):
    """Detailed serializer for Patient model."""

    blood_requests = serializers.SerializerMethodField()

    class Meta(PatientSerializer.Meta):
        fields = PatientSerializer.Meta.fields + ['blood_requests']

    def get_blood_requests(self, obj):
        from requests.serializers import BloodRequestSerializer
        return BloodRequestSerializer(obj.blood_requests.all(), many=True).data
