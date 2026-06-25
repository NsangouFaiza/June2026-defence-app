from rest_framework import serializers
from .models import BloodInventory


class BloodInventorySerializer(serializers.ModelSerializer):
    """Serializer for BloodInventory model."""
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)

    class Meta:
        model = BloodInventory
        fields = [
            'id', 'hospital', 'hospital_name', 'blood_group', 'quantity',
            'collection_date', 'expiration_date', 'status', 'donor',
            'is_expired', 'days_until_expiry', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'is_expired', 'days_until_expiry']
