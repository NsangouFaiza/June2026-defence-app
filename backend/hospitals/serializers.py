from rest_framework import serializers
from .models import Hospital, HospitalStaff


class HospitalSerializer(serializers.ModelSerializer):
    """Serializer for Hospital model."""

    class Meta:
        model = Hospital
        fields = [
            'id', 'name', 'address', 'city', 'region', 'phone_number',
            'email', 'description', 'latitude', 'longitude',
            'opening_hours', 'has_blood_bank', 'has_emergency_services', 'services',
            'is_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class HospitalStaffSerializer(serializers.ModelSerializer):
    """Serializer for HospitalStaff model."""
    user_name = serializers.CharField(source='user.full_name', read_only=True)
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)

    class Meta:
        model = HospitalStaff
        fields = [
            'id', 'user', 'user_name', 'hospital', 'hospital_name',
            'position', 'department', 'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
