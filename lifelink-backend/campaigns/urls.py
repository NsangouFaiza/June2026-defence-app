from django.urls import path
from .views import CampaignListCreateView, CampaignDetailView, CampaignActionViewSet

urlpatterns = [
    path('', CampaignListCreateView.as_view(), name='campaign-list'),
    path('my-campaigns/', CampaignActionViewSet.as_view({'get': 'my_campaigns'}), name='my-campaigns'),
    path('<int:pk>/', CampaignDetailView.as_view(), name='campaign-detail'),
    path('<int:pk>/register/', CampaignActionViewSet.as_view({'post': 'register'}), name='campaign-register'),
    path('<int:pk>/unregister/', CampaignActionViewSet.as_view({'post': 'unregister'}), name='campaign-unregister'),
    path('<int:pk>/send/', CampaignActionViewSet.as_view({'post': 'send_campaign'}), name='campaign-send'),
    path('<int:pk>/target-donors/', CampaignActionViewSet.as_view({'get': 'target_donors'}), name='campaign-target-donors'),
    
    path('<int:pk>/duplicate/', CampaignActionViewSet.as_view({'post': 'duplicate'}), name='campaign-duplicate'),
    path('<int:pk>/publish/', CampaignActionViewSet.as_view({'post': 'publish'}), name='campaign-publish'),
    path('<int:pk>/unpublish/', CampaignActionViewSet.as_view({'post': 'unpublish'}), name='campaign-unpublish'),
    path('<int:pk>/archive/', CampaignActionViewSet.as_view({'post': 'archive'}), name='campaign-archive'),
    path('<int:pk>/restore/', CampaignActionViewSet.as_view({'post': 'restore'}), name='campaign-restore'),
    path('<int:pk>/increment-views/', CampaignActionViewSet.as_view({'post': 'increment_views'}), name='campaign-increment-views'),
    
    path('<int:pk>/participants/', CampaignActionViewSet.as_view({'get': 'participants'}), name='campaign-participants'),
    path('<int:pk>/approve-registration/', CampaignActionViewSet.as_view({'post': 'approve_registration'}), name='campaign-approve-registration'),
    path('<int:pk>/reject-registration/', CampaignActionViewSet.as_view({'post': 'reject_registration'}), name='campaign-reject-registration'),
    path('<int:pk>/attendance-check/', CampaignActionViewSet.as_view({'post': 'attendance_check'}), name='campaign-attendance-check'),
    path('<int:pk>/statistics/', CampaignActionViewSet.as_view({'get': 'statistics'}), name='campaign-statistics'),
    path('<int:pk>/export-participants/', CampaignActionViewSet.as_view({'get': 'export_participants'}), name='campaign-export-participants'),
]
