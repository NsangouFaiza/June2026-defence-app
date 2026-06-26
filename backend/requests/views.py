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

    @action(detail=False, methods=['get', 'post'], url_path='emergency')
    def emergency(self, request):
        """Get or create emergency blood requests."""
        if request.method == 'POST':
            from patients.models import Patient
            try:
                patient = Patient.objects.get(user=request.user)
            except Patient.DoesNotExist:
                return Response(
                    {'error': 'Patient profile not found. Only patients can create blood requests.'},
                    status=status.HTTP_404_NOT_FOUND,
                )

            data = request.data.copy()
            data['is_emergency'] = True
            data['urgency'] = 'CRITICAL'
            if 'hospital_id' not in data or not data['hospital_id']:
                from hospitals.models import Hospital
                first_hospital = Hospital.objects.first()
                if first_hospital:
                    data['hospital_id'] = first_hospital.id
            
            serializer = self.get_serializer(data=data)
            if serializer.is_valid():
                serializer.save(patient=patient)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        # GET method
        queryset = BloodRequest.objects.filter(
            is_emergency=True,
            status__in=['PENDING', 'APPROVED', 'PROCESSING'],
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

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        """Approve a blood request (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        blood_request.status = 'APPROVED'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject a blood request (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        reason = request.data.get('reason', '')
        blood_request.status = 'REJECTED'
        blood_request.reason = reason
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def fulfill(self, request, pk=None):
        """Mark request as fulfilled (hospital staff only)."""
        if request.user.role not in ('hospital_staff', 'blood_bank_admin', 'system_admin'):
            return Response({'error': 'Permission denied'}, status=status.HTTP_403_FORBIDDEN)

        blood_request = self.get_object()
        blood_request.status = 'FULFILLED'
        blood_request.save()
        serializer = self.get_serializer(blood_request)
        return Response(serializer.data)
