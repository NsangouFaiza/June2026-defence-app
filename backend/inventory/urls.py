from django.urls import path, include
from rest_framework.routers import DefaultRouter
from . import views

router = DefaultRouter()
router.register(r'lab-records', views.LabTestRecordViewSet, basename='lab-records')
router.register(r'', views.BloodInventoryViewSet)

urlpatterns = [
    path('', include(router.urls)),
]
