from django.urls import path
from .views import NotificationListView, NotificationDetailView, NotificationActionViewSet, SendNotificationView

urlpatterns = [
    path('', NotificationListView.as_view(), name='notification-list'),
    path('<int:pk>/', NotificationDetailView.as_view(), name='notification-detail'),
    path('mark-read/<int:pk>/', NotificationActionViewSet.as_view({'post': 'mark_read'}), name='notification-mark-read'),
    path('mark-all-read/', NotificationActionViewSet.as_view({'post': 'mark_all_read'}), name='notification-mark-all-read'),
    path('send/', SendNotificationView.as_view(), name='notification-send'),
]
