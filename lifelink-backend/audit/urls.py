from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'', views.AdminUserViewSet, basename='admin-users')

urlpatterns = [
    path('', include(router.urls)),
    path('statistics/', views.AdminStatisticsView.as_view(), name='admin-statistics'),
]
