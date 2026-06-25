from django.urls import path
from .views import EligibilityCheckListCreateView, EligibilityCheckDetailView, CheckEligibilityAPIView

urlpatterns = [
    path('', EligibilityCheckListCreateView.as_view(), name='eligibility-list'),
    path('<int:pk>/', EligibilityCheckDetailView.as_view(), name='eligibility-detail'),
    path('check/', CheckEligibilityAPIView.as_view(), name='check-eligibility'),
]
