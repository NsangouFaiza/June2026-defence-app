from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets
from django.db.models import Count, Sum

from .models import Badge, DonorReward
from .serializers import BadgeSerializer, DonorRewardSerializer


class BadgeListView(generics.ListAPIView):
    queryset = Badge.objects.all()
    serializer_class = BadgeSerializer
    permission_classes = [permissions.IsAuthenticated]


class DonorRewardListCreateView(generics.ListCreateAPIView):
    queryset = DonorReward.objects.all()
    serializer_class = DonorRewardSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        donor_id = self.kwargs.get('donor_id')
        if donor_id:
            return DonorReward.objects.filter(donor_id=donor_id)
        return DonorReward.objects.all()


class RewardActionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['get'])
    def my_rewards(self, request):
        """Get current user's rewards."""
        try:
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            rewards = DonorReward.objects.filter(donor=donor)
            serializer = DonorRewardSerializer(rewards, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response(
                {'error': 'Donor profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=False, methods=['get'])
    def leaderboard(self, request):
        """Get top donors leaderboard."""
        from donors.models import Donor
        donors = Donor.objects.filter(user__is_active=True).order_by('-points', '-total_donations')[:50]
        data = []
        for d in donors:
            data.append({
                'id': d.id,
                'name': d.user.full_name,
                'points': d.points,
                'level': d.level,
                'total_donations': d.total_donations,
            })
        return Response(data)
