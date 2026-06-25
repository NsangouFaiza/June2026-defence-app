from rest_framework import serializers
from .models import Badge, DonorReward


class BadgeSerializer(serializers.ModelSerializer):
    class Meta:
        model = Badge
        fields = '__all__'


class DonorRewardSerializer(serializers.ModelSerializer):
    badge = BadgeSerializer(read_only=True)
    badge_id = serializers.IntegerField(write_only=True)

    class Meta:
        model = DonorReward
        fields = '__all__'
        read_only_fields = ['awarded_at']
