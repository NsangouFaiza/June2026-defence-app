from django.urls import path
from .views import CampaignListCreateView, CampaignDetailView, CampaignActionViewSet

urlpatterns = [
    path('', CampaignListCreateView.as_view(), name='campaign-list'),
    path('my-campaigns/', CampaignActionViewSet.as_view({'get': 'my_campaigns'}), name='my-campaigns'),
    path('<int:pk>/', CampaignDetailView.as_view(), name='campaign-detail'),
    path('<int:pk>/register/', CampaignActionViewSet.as_view({'post': 'register'}), name='campaign-register'),
    path('<int:pk>/unregister/', CampaignActionViewSet.as_view({'post': 'unregister'}), name='campaign-unregister'),
]
