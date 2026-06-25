from rest_framework import serializers
from .models import Donor


class DonorSerializer(serializers.ModelSerializer):
    """Serializer for Donor model."""

    user = serializers.SerializerMethodField()
    total_donations = serializers.SerializerMethodField()
    total_blood_units = serializers.SerializerMethodField()
    lives_saved = serializers.SerializerMethodField()

    class Meta:
        model = Donor
        fields = [
            'id', 'user', 'total_donations', 'total_blood_units', 'lives_saved',
            'last_donation_date', 'next_eligible_date', 'is_eligible',
            'eligibility_reason', 'points', 'level', 'is_anonymous',
            'is_available', 'eligibility_status',
            'weight', 'height', 'latitude', 'longitude',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_user(self, obj):
        from users.serializers import UserSerializer
        return UserSerializer(obj.user).data

    def get_total_donations(self, obj):
        return obj.donations.count()

    def get_total_blood_units(self, obj):
        from django.db.models import Sum
        return obj.donations.aggregate(
            total=Sum('quantity_ml')
        )['total'] or 0

    def get_lives_saved(self, obj):
        return obj.donations.count() * 3


class DonorDetailSerializer(DonorSerializer):
    """Detailed serializer for Donor model."""

    donations = serializers.SerializerMethodField()
    rewards = serializers.SerializerMethodField()

    class Meta(DonorSerializer.Meta):
        fields = DonorSerializer.Meta.fields + ['donations', 'rewards']

    def get_donations(self, obj):
        from donations.serializers import DonationSerializer
        return DonationSerializer(obj.donations.all(), many=True).data

    def get_rewards(self, obj):
        from rewards.serializers import DonorRewardSerializer
        return DonorRewardSerializer(obj.rewards.all(), many=True).data
