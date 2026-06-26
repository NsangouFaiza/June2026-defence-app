from rest_framework import serializers
from .models import Donation


class DonationSerializer(serializers.ModelSerializer):
    donor_name = serializers.CharField(source='donor.user.full_name', read_only=True)
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)
    units = serializers.IntegerField(source='quantity_ml')
    notes = serializers.CharField(source='screening_notes', required=False, allow_blank=True, default='')
    date = serializers.DateTimeField(source='created_at', read_only=True)
    verified_at = serializers.DateTimeField(source='updated_at', read_only=True)

    class Meta:
        model = Donation
        fields = [
            'id', 'donor', 'donor_name', 'hospital', 'hospital_name',
            'appointment', 'blood_group', 'units', 'status', 'notes',
            'date', 'verified_at', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'date', 'verified_at']
