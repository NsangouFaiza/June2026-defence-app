from django.db.models import Count, Sum, Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils import timezone
from datetime import timedelta

from .models import Donor
from .serializers import DonorSerializer, DonorDetailSerializer


class DonorViewSet(viewsets.ModelViewSet):
    """ViewSet for Donor model."""

    queryset = Donor.objects.all()
    serializer_class = DonorSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['is_available', 'eligibility_status']
    search_fields = ['user__first_name', 'user__last_name', 'user__email']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return DonorDetailSerializer
        return DonorSerializer

    @action(detail=False, methods=['get'])
    def eligible(self, request):
        """Get eligible donors."""
        queryset = Donor.objects.filter(
            is_available=True,
            eligibility_status='eligible',
            user__is_active=True,
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def by_blood_group(self, request):
        """Get donors by blood group."""
        blood_group = request.query_params.get('blood_group')
        if not blood_group:
            return Response(
                {'error': 'blood_group parameter is required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = Donor.objects.filter(
            user__blood_group=blood_group,
            is_available=True,
            eligibility_status='eligible',
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get nearby donors (requires lat/lng)."""
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')
        radius = request.query_params.get('radius', 50)  # km

        if not lat or not lng:
            return Response(
                {'error': 'lat and lng parameters are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        queryset = Donor.objects.filter(
            is_available=True,
            eligibility_status='eligible',
        )
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_profile(self, request):
        """Get current user's donor profile."""
        try:
            donor = Donor.objects.get(user=request.user)
            serializer = DonorDetailSerializer(donor)
            return Response(serializer.data)
        except Donor.DoesNotExist:
            return Response(
                {'error': 'Donor profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=True, methods=['post'])
    def update_eligibility(self, request, pk=None):
        """Update donor eligibility status."""
        donor = self.get_object()
        status_value = request.data.get('status')
        if status_value in ['eligible', 'temporarily_ineligible', 'permanently_ineligible']:
            donor.eligibility_status = status_value
            donor.save()
            serializer = self.get_serializer(donor)
            return Response(serializer.data)
        return Response(
            {'error': 'Invalid status'},
            status=status.HTTP_400_BAD_REQUEST,
        )
