from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Patient
from .serializers import PatientSerializer, PatientDetailSerializer


class PatientViewSet(viewsets.ModelViewSet):
    """ViewSet for Patient model."""

    queryset = Patient.objects.all()
    serializer_class = PatientSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['user__blood_group']
    search_fields = ['user__first_name', 'user__last_name', 'user__email']

    def get_serializer_class(self):
        if self.action == 'retrieve':
            return PatientDetailSerializer
        return PatientSerializer

    @action(detail=False, methods=['get'])
    def my_profile(self, request):
        """Get current user's patient profile."""
        try:
            patient = Patient.objects.get(user=request.user)
            serializer = PatientDetailSerializer(patient)
            return Response(serializer.data)
        except Patient.DoesNotExist:
            return Response(
                {'error': 'Patient profile not found'},
                status=status.HTTP_404_NOT_FOUND,
            )
