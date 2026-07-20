from rest_framework import generics, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets

from .models import Campaign
from .serializers import CampaignSerializer


class CampaignListCreateView(generics.ListCreateAPIView):
    queryset = Campaign.objects.all()
    serializer_class = CampaignSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    filterset_fields = ['status', 'campaign_type']


class CampaignDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = Campaign.objects.all()
    serializer_class = CampaignSerializer
    permission_classes = [permissions.IsAuthenticated]


class CampaignActionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=True, methods=['post'])
    def register(self, request, pk=None):
        """Register current user for a campaign."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            campaign.participants.add(donor)
            return Response({'message': 'Successfully registered for campaign'})
        except Campaign.DoesNotExist:
            return Response(
                {'error': 'Campaign not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
        except Donor.DoesNotExist:
            return Response(
                {'error': 'Donor profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=['post'])
    def unregister(self, request, pk=None):
        """Unregister current user from a campaign."""
        try:
            campaign = Campaign.objects.get(pk=pk)
            from donors.models import Donor
            donor = Donor.objects.get(user=request.user)
            campaign.participants.remove(donor)
            return Response({'message': 'Successfully unregistered from campaign'})
        except Campaign.DoesNotExist:
            return Response({'error': 'Campaign not found'}, status=status.HTTP_404_NOT_FOUND)
        except Donor.DoesNotExist:
            return Response({'error': 'Donor profile not found'}, status=status.HTTP_404_NOT_FOUND)

    @action(detail=False, methods=['get'])
    def my_campaigns(self, request):
        """Get campaigns current donor is registered for."""
        from donors.models import Donor
        try:
            donor = Donor.objects.get(user=request.user)
            campaigns = donor.campaigns.all()
            serializer = CampaignSerializer(campaigns, many=True)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response([])

