from django.urls import path
from .views import CampaignListCreateView, CampaignDetailView, CampaignActionViewSet

urlpatterns = [
    path('', CampaignListCreateView.as_view(), name='campaign-list'),
    path('<int:pk>/', CampaignDetailView.as_view(), name='campaign-detail'),
    path('<int:pk>/register/', CampaignActionViewSet.as_view({'post': 'register'}), name='campaign-register'),
]
