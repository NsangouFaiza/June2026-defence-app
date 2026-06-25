from django.urls import path
from .views import PaymentListCreateView, PaymentDetailView, PaymentActionViewSet

urlpatterns = [
    path('', PaymentListCreateView.as_view(), name='payment-list'),
    path('<int:pk>/', PaymentDetailView.as_view(), name='payment-detail'),
    path('initiate/', PaymentActionViewSet.as_view({'post': 'initiate'}), name='payment-initiate'),
    path('verify/', PaymentActionViewSet.as_view({'post': 'verify'}), name='payment-verify'),
]
