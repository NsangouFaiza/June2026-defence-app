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
    reason = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    notes = serializers.CharField(required=False, allow_null=True, allow_blank=True)
    donor_id = serializers.IntegerField(write_only=True, required=False, allow_null=True)
    donor = serializers.IntegerField(source='donor.id', read_only=True, allow_null=True)
    donor_name = serializers.CharField(source='donor.user.full_name', read_only=True, allow_null=True)
    donor_phone = serializers.CharField(source='donor.user.phone_number', read_only=True, allow_null=True)
    donor_email = serializers.CharField(source='donor.user.email', read_only=True, allow_null=True)
    appointment_details = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = BloodRequest
        fields = [
            'id', 'patient_id', 'hospital_id', 'patient_data', 'hospital_data',
            'patient', 'patient_name', 'hospital', 'hospital_name',
            'blood_group', 'quantity', 'urgency', 'is_emergency',
            'status', 'reason', 'notes', 'payment_status', 'payment_reference',
            'fulfillment_type', 'donor_id', 'donor', 'donor_name', 'donor_phone',
            'donor_email', 'appointment_details', 'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'payment_status', 'payment_reference']

    def get_appointment_details(self, obj):
        appointment = obj.appointments.first()
        if appointment:
            return {
                'id': appointment.id,
                'date': appointment.scheduled_date.isoformat(),
                'time': appointment.scheduled_time.strftime('%H:%M') if hasattr(appointment.scheduled_time, 'strftime') else str(appointment.scheduled_time),
                'status': appointment.status,
                'notes': appointment.notes,
                'hospital_name': appointment.hospital.name,
                'hospital_address': appointment.hospital.address or '',
                'donor_name': appointment.donor.user.full_name,
                'donor_phone': appointment.donor.user.phone_number,
            }
        return None

    def get_patient_data(self, obj):
        from patients.serializers import PatientSerializer
        return PatientSerializer(obj.patient).data

    def get_hospital_data(self, obj):
        from hospitals.serializers import HospitalSerializer
        return HospitalSerializer(obj.hospital).data

    def to_internal_value(self, data):
        if hasattr(data, 'copy'):
            data = data.copy()
        elif isinstance(data, dict):
            data = dict(data)
        if isinstance(data, dict):
            if 'urgency_level' in data and 'urgency' not in data:
                data['urgency'] = data['urgency_level']
            if data.get('urgency') == 'NORMAL':
                data['urgency'] = 'MEDIUM'
            if data.get('fulfillment_type') == 'DONOR_DISPATCH':
                data['fulfillment_type'] = 'DIRECT_DONATION'
        return super().to_internal_value(data)

    def validate(self, attrs):
        patient_id = attrs.pop('patient_id', None)
        hospital_id = attrs.pop('hospital_id', None)
        donor_id = attrs.pop('donor_id', None)
        is_emergency = attrs.get('is_emergency', False)

        # Normalize null values to empty strings to prevent database IntegrityError
        attrs['reason'] = attrs.get('reason') or ''
        attrs['notes'] = attrs.get('notes') or ''

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
        elif is_emergency and not hospital_id:
            from hospitals.models import Hospital
            first_h = Hospital.objects.filter(is_active=True).first() or Hospital.objects.first()
            if first_h:
                attrs['hospital'] = first_h

        if donor_id:
            from donors.models import Donor
            try:
                attrs['donor'] = Donor.objects.get(pk=donor_id)
            except Donor.DoesNotExist:
                raise serializers.ValidationError({'donor_id': 'Invalid donor ID'})

        return attrs
