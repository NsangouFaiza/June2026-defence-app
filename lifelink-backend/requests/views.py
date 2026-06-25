from django.db.models import Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import BloodRequest
from .serializers import BloodRequestSerializer


class BloodRequestViewSet(viewsets.ModelViewSet):
    """ViewSet for BloodRequest model."""

    queryset = BloodRequest.objects.all()
    serializer_class = BloodRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['patient', 'hospital', 'blood_group', 'status', 'urgency']
    search_fields = ['patient__user__first_name', 'patient__user__last_name', 'hospital__name']

    def perform_create(self, serializer):
        from patients.models import Patient
        patient = Patient.objects.get(user=self.request.user)
        serializer.save(patient=patient)

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'emergency']:
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticated()]

    @action(detail=False, methods=['get'])
    def emergency(self, request):
        """Get emergency blood requests."""
        queryset = BloodRequest.objects.filter(
            is_emergency=True,
            status__in=['pending', 'approved', 'processing'],
        ).order_by('-urgency', '-created_at')
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def my_requests(self, request):
        """Get current patient's requests."""
        try:
            from patients.models import Patient
            patient = Patient.objects.get(user=request.user)
            queryset = BloodRequest.objects.filter(patient=patient)
            serializer = self.get_serializer(queryset, many=True)
            return Response(serializer.data)
        except Patient.DoesNotExist:
            return Response(
                {'error': 'Patient profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=False, methods=['post'])
    def emergency_create(self, request):
        """Create an emergency blood request."""
        data = request.data.copy()
        data['is_emergency'] = True
        data['urgency'] = 'CRITICAL'
        serializer = self.get_serializer(data=data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve a blood request (hospital staff only)."""
        blood_request = self.get_object()
        blood_request.status = 'APPROVED'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject a blood request (hospital staff only)."""
        blood_request = self.get_object()
        reason = request.data.get('reason', '')
        blood_request.status = 'REJECTED'
        blood_request.reason = reason
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def fulfill(self, request, pk=None):
        """Mark request as fulfilled."""
        blood_request = self.get_object()
        blood_request.status = 'FULFILLED'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)
