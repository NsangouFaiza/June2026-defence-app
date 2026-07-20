from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'health-records', views.DonorHealthRecordViewSet, basename='health-records')
router.register(r'', views.DonorViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
