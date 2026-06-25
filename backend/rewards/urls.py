from django.urls import path
from .views import BadgeListView, DonorRewardListCreateView, RewardActionViewSet

urlpatterns = [
    path('badges/', BadgeListView.as_view(), name='badge-list'),
    path('donor-rewards/', DonorRewardListCreateView.as_view(), name='donor-reward-list'),
    path('donor-rewards/<int:donor_id>/', DonorRewardListCreateView.as_view(), name='donor-reward-detail'),
    path('my-rewards/', RewardActionViewSet.as_view({'get': 'my_rewards'}), name='my-rewards'),
    path('leaderboard/', RewardActionViewSet.as_view({'get': 'leaderboard'}), name='leaderboard'),
]
