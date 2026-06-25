from django.urls import path
from .views import ReportViewSet

urlpatterns = [
    path('monthly-donations/', ReportViewSet.as_view({'get': 'monthly_donations'}), name='monthly-donations'),
    path('blood-stock/', ReportViewSet.as_view({'get': 'blood_stock'}), name='blood-stock'),
    path('statistics/', ReportViewSet.as_view({'get': 'statistics'}), name='report-statistics'),
]
