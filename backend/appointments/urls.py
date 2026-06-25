from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

router = DefaultRouter()
router.register(r'', views.AppointmentViewSet)

urlpatterns = [
    path('', include(router.urls)),
    path('available-slots/', views.AppointmentViewSet.as_view({'get': 'available_slots'}), name='available-slots'),
]
