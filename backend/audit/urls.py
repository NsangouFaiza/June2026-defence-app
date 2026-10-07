from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'users', views.AdminUserViewSet, basename='admin-users')
router.register(r'hospitals', views.AdminHospitalViewSet, basename='admin-hospitals')

urlpatterns = [
    path('statistics/', views.AdminStatisticsView.as_view(), name='admin-statistics'),
    path('audit-logs/', views.AuditLogListView.as_view(), name='admin-audit-logs'),
    path('', include(router.urls)),
]
