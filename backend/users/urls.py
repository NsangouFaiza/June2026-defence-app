from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView
from . import views

urlpatterns = [
    path('register/', views.register, name='register'),
    path('login/', views.CustomTokenObtainPairView.as_view(), name='login'),
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('me/', views.get_current_user, name='current_user'),
    path('update-profile/', views.update_profile, name='update_profile'),
    path('profile-picture/', views.upload_profile_picture, name='upload_profile_picture'),
    path('remove-profile-picture/', views.delete_profile_picture, name='delete_profile_picture'),
    path('change-password/', views.change_password, name='change_password'),
    path('forgot-password/', views.forgot_password, name='forgot_password'),
    path('reset-password/', views.reset_password, name='reset_password'),
    path('logout/', views.logout, name='logout'),
    path('security-settings/', views.get_security_settings, name='get_security_settings'),
    path('security-settings/update/', views.update_security_settings, name='update_security_settings'),
    path('security-settings/terminate-session/', views.terminate_session, name='terminate_session'),
    path('contacts/donors/', views.list_donor_contacts, name='list_donor_contacts'),
    path('contacts/patients/', views.list_patient_contacts, name='list_patient_contacts'),
    path('contacts/staff/', views.list_staff_contacts, name='list_staff_contacts'),
]
