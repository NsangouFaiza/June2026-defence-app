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


from .models import LabTestRecord

class LabTestRecordSerializer(serializers.ModelSerializer):
    """Serializer for LabTestRecord model."""
    donor_name = serializers.SerializerMethodField()
    tested_by_name = serializers.SerializerMethodField()

    class Meta:
        model = LabTestRecord
        fields = [
            'id', 'donor', 'donor_name', 'inventory_unit', 'sample_code',
            'blood_group', 'rh_factor', 'hiv_status', 'hep_b_status',
            'hep_c_status', 'syphilis_status', 'malaria_status',
            'hemoglobin_g_dl', 'unit_status', 'abnormal_findings',
            'has_abnormal_findings', 'tested_by', 'tested_by_name',
            'tested_at', 'created_at',
        ]
        read_only_fields = ['id', 'sample_code', 'created_at', 'donor_name', 'tested_by_name']

    def get_donor_name(self, obj):
        if obj.donor and obj.donor.user:
            return obj.donor.user.full_name
        return "N/A"

    def get_tested_by_name(self, obj):
        if obj.tested_by:
            return obj.tested_by.full_name
        return "N/A"

