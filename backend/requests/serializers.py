from rest_framework import serializers
from .models import BloodRequest


class BloodRequestSerializer(serializers.ModelSerializer):
    """Serializer for BloodRequest model."""

    patient_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)
    hospital_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)
    patient_data = serializers.SerializerMethodField(read_only=True)
    hospital_data = serializers.SerializerMethodField(read_only=True)
    patient = serializers.IntegerField(source='patient.id', read_only=True)
    patient_name = serializers.CharField(source='patient.user.full_name', read_only=True)
    hospital = serializers.IntegerField(source='hospital.id', read_only=True, allow_null=True)
    hospital_name = serializers.CharField(source='hospital.name', read_only=True, allow_null=True)

    class Meta:
        model = BloodRequest
        fields = [
            'id', 'patient_id', 'hospital_id', 'patient_data', 'hospital_data',
            'patient', 'patient_name', 'hospital', 'hospital_name',
            'blood_group', 'quantity', 'urgency', 'is_emergency',
            'status', 'reason', 'notes', 'payment_status', 'payment_reference',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'payment_status', 'payment_reference']

    def get_patient_data(self, obj):
        from patients.serializers import PatientSerializer
        return PatientSerializer(obj.patient).data

    def get_hospital_data(self, obj):
        from hospitals.serializers import HospitalSerializer
        return HospitalSerializer(obj.hospital).data

    def validate(self, attrs):
        patient_id = attrs.pop('patient_id', None)
        hospital_id = attrs.pop('hospital_id', None)
        is_emergency = attrs.get('is_emergency', False)

        if not hospital_id and not is_emergency:
            raise serializers.ValidationError({'hospital_id': 'This field is required.'})

        if patient_id:
            from patients.models import Patient
            try:
                attrs['patient'] = Patient.objects.get(pk=patient_id)
            except Patient.DoesNotExist:
                raise serializers.ValidationError({'patient_id': 'Invalid patient ID'})

        if hospital_id:
            from hospitals.models import Hospital
            try:
                attrs['hospital'] = Hospital.objects.get(pk=hospital_id)
            except Hospital.DoesNotExist:
                raise serializers.ValidationError({'hospital_id': 'Invalid hospital ID'})

        return attrs
