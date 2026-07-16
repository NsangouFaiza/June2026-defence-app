from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView
from datetime import datetime, timedelta
from django.db.models import Sum, Count

from .models import EligibilityCheck
from .serializers import EligibilityCheckSerializer


class EligibilityCheckListCreateView(generics.ListCreateAPIView):
    queryset = EligibilityCheck.objects.all()
    serializer_class = EligibilityCheckSerializer
    permission_classes = [permissions.IsAuthenticated]
    filterset_fields = ['donor', 'status']


class EligibilityCheckDetailView(generics.RetrieveUpdateDestroyAPIView):
    queryset = EligibilityCheck.objects.all()
    serializer_class = EligibilityCheckSerializer
    permission_classes = [permissions.IsAuthenticated]


class CheckEligibilityAPIView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        data = request.data
        age = data.get('age')
        weight = data.get('weight')
        has_recent_surgery = data.get('has_recent_surgery', False)
        is_pregnant = data.get('is_pregnant', False)
        has_infectious_disease = data.get('has_infectious_disease', False)
        is_on_medication = data.get('is_on_medication', False)
        has_medical_condition = data.get('has_medical_condition', False)

        reasons = []
        if age and (age < 18 or age > 65):
            reasons.append('Age must be between 18 and 65')
        if weight and weight < 50:
            reasons.append('Weight must be at least 50 kg')
        if has_recent_surgery:
            reasons.append('Recent surgery')
        if is_pregnant:
            reasons.append('Pregnancy')
        if has_infectious_disease:
            reasons.append('Infectious disease')
        if is_on_medication:
            reasons.append('Currently on medication')
        if has_medical_condition:
            reasons.append('Medical condition')

        # Update donor profile if user is authenticated and registered as a donor
        if request.user and request.user.is_authenticated:
            from donors.models import Donor
            try:
                donor = Donor.objects.get(user=request.user)
                if weight:
                    donor.weight = float(weight)
                if reasons:
                    donor.is_eligible = False
                    donor.eligibility_status = 'temporarily_ineligible'
                    donor.eligibility_reason = '; '.join(reasons)
                else:
                    donor.is_eligible = True
                    donor.eligibility_status = 'eligible'
                    donor.eligibility_reason = ''
                donor.save()
            except Donor.DoesNotExist:
                pass

        if reasons:
            return Response({
                'status': 'TEMP_INELIGIBLE',
                'message': 'You are temporarily ineligible to donate blood',
                'reasons': reasons,
            })

        return Response({
            'status': 'ELIGIBLE',
            'message': 'You are eligible to donate blood',
        })
