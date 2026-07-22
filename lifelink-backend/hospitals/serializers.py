from rest_framework import serializers
from .models import Hospital, HospitalStaff
from payments.models import HospitalSubscriptionPayment


class HospitalSerializer(serializers.ModelSerializer):
    """Serializer for Hospital model."""
    is_subscription_active = serializers.BooleanField(read_only=True)

    class Meta:
        model = Hospital
        fields = [
            'id', 'name', 'address', 'city', 'region', 'phone_number',
            'email', 'description', 'latitude', 'longitude',
            'opening_hours', 'has_blood_bank', 'has_emergency_services', 'services',
            'is_active', 'subscription_end_date', 'subscription_status',
            'is_subscription_active', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_subscription_active']


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


class HospitalSubscriptionPaymentSerializer(serializers.ModelSerializer):
    """Serializer for HospitalSubscriptionPayment model."""
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)
    staff_name = serializers.CharField(source='staff_user.full_name', read_only=True)

    class Meta:
        model = HospitalSubscriptionPayment
        fields = [
            'id', 'hospital', 'hospital_name', 'staff_user', 'staff_name',
            'amount', 'months', 'payment_method', 'status', 'transaction_id',
            'invoice_number', 'phone_number', 'external_reference', 'paid_at',
            'subscription_period_start', 'subscription_period_end',
            'response_data', 'created_at', 'updated_at',
        ]
        read_only_fields = [
            'id', 'transaction_id', 'invoice_number', 'paid_at',
            'subscription_period_start', 'subscription_period_end',
            'created_at', 'updated_at',
        ]

