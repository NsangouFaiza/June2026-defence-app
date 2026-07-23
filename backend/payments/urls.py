from django.urls import path
from .views import PaymentListCreateView, PaymentDetailView, PaymentActionViewSet, PaymentHistoryView, CampayWebhookView

urlpatterns = [
    path('', PaymentListCreateView.as_view(), name='payment-list'),
    path('history/', PaymentHistoryView.as_view(), name='payment-history'),
    path('<int:pk>/', PaymentDetailView.as_view(), name='payment-detail'),
    path('initiate/', PaymentActionViewSet.as_view({'post': 'initiate'}), name='payment-initiate'),
    path('verify/', PaymentActionViewSet.as_view({'post': 'verify'}), name='payment-verify'),
    path('webhook/campay/', CampayWebhookView.as_view(), name='campay-webhook'),
]

