from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'', views.BloodRequestViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('emergency/', views.BloodRequestViewSet.as_view({'post': 'emergency_create'}), name='emergency-request'),
]
