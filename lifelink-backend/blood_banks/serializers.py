from rest_framework import serializers
from .models import BloodBank


class BloodBankSerializer(serializers.ModelSerializer):
    """Serializer for BloodBank model."""

    class Meta:
        model = BloodBank
        fields = [
            'id', 'name', 'address', 'city', 'region', 'phone_number',
            'email', 'manager_name', 'capacity', 'current_stock',
            'is_active', 'created_at',
        ]
        read_only_fields = ['id', 'created_at']
