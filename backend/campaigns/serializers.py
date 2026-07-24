from rest_framework import serializers
from .models import Campaign, CampaignRegistration
from donors.serializers import DonorDetailSerializer


class CampaignSerializer(serializers.ModelSerializer):
    participants_count = serializers.SerializerMethodField()
    registered_count = serializers.SerializerMethodField()
    attended_count = serializers.SerializerMethodField()
    donated_count = serializers.SerializerMethodField()
    is_registered = serializers.SerializerMethodField()

    class Meta:
        model = Campaign
        fields = '__all__'
        read_only_fields = ['created_at', 'updated_at']

    def get_participants_count(self, obj):
        return obj.registrations.exclude(status='CANCELLED').count()

    def get_registered_count(self, obj):
        return obj.registrations.filter(status__in=['REGISTERED', 'APPROVED', 'ATTENDED']).count()

    def get_attended_count(self, obj):
        return obj.registrations.filter(status='ATTENDED').count()

    def get_donated_count(self, obj):
        return obj.registrations.filter(donated=True).count()

    def get_is_registered(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            try:
                from donors.models import Donor
                donor = Donor.objects.get(user=request.user)
                return obj.registrations.filter(donor=donor).exclude(status='CANCELLED').exists()
            except Donor.DoesNotExist:
                pass
        return False


class CampaignRegistrationSerializer(serializers.ModelSerializer):
    donor_details = DonorDetailSerializer(source='donor', read_only=True)

    class Meta:
        model = CampaignRegistration
        fields = '__all__'

