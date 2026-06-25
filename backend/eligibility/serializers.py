from rest_framework import serializers
from .models import EligibilityCheck


class EligibilityCheckSerializer(serializers.ModelSerializer):
    class Meta:
        model = EligibilityCheck
        fields = '__all__'
        read_only_fields = ['created_at']
