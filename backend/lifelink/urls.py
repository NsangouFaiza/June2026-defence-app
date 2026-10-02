"""
URL configuration for lifelink project.
"""

from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/users/', include('users.urls')),
    path('api/hospitals/', include('hospitals.urls')),
    path('api/blood-banks/', include('blood_banks.urls')),
    path('api/inventory/', include('inventory.urls')),
    path('api/donors/', include('donors.urls')),
    path('api/patients/', include('patients.urls')),
    path('api/requests/', include('requests.urls')),
    path('api/appointments/', include('appointments.urls')),
    path('api/donations/', include('donations.urls')),
    path('api/eligibility/', include('eligibility.urls')),
    path('api/messages/', include('messages_app.urls')),
    path('api/notifications/', include('notifications.urls')),
    path('api/campaigns/', include('campaigns.urls')),
    path('api/rewards/', include('rewards.urls')),
    path('api/payments/', include('payments.urls')),
    path('api/admin/', include('audit.urls')),
    path('api/reports/', include('reports.urls')),
    path('api/ai/', include('ai_assistant.urls')),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += [
        path('__debug__/', include('debug_toolbar.urls')),
    ]
