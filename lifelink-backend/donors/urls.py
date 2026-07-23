from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'health-records', views.DonorHealthRecordViewSet, basename='health-records')
router.register(r'', views.DonorViewSet)

urlpatterns = [
    path('verify-badge/<str:donor_code>/', views.verify_badge_view, name='verify_badge'),
    path('', include(router.urls)),
]
