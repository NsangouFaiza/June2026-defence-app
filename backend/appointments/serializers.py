from rest_framework import serializers
from .models import Appointment


class AppointmentSerializer(serializers.ModelSerializer):
    date = serializers.DateField(source='scheduled_date')
    time = serializers.TimeField(source='scheduled_time')
    donor_name = serializers.CharField(source='donor.user.full_name', read_only=True)
    hospital_name = serializers.CharField(source='hospital.name', read_only=True)
    notes = serializers.CharField(required=False, allow_null=True, allow_blank=True)

    class Meta:
        model = Appointment
        fields = [
            'id', 'donor', 'donor_name', 'hospital', 'hospital_name',
            'blood_request', 'date', 'time', 'status', 'notes', 'confirmed_by',
            'completed_at', 'created_at', 'updated_at'
        ]
        read_only_fields = ['created_at', 'updated_at', 'donor']

    def validate_notes(self, value):
        return value or ''
