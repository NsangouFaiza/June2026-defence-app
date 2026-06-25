from django.contrib import admin
from django.contrib.auth.admin import UserAdmin
from .models import User


@admin.register(User)
class CustomUserAdmin(UserAdmin):
    list_display = ('email', 'full_name', 'role', 'blood_group', 'is_active', 'is_staff')
    list_filter = ('role', 'is_active', 'is_staff', 'blood_group')
    search_fields = ('email', 'full_name', 'phone_number')
    ordering = ('-date_joined',)

    fieldsets = (
        (None, {'fields': ('email', 'password')}),
        ('Personal Info', {'fields': ('full_name', 'gender', 'date_of_birth', 'blood_group', 'phone_number', 'address', 'city', 'region')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'role', 'groups', 'user_permissions')}),
        ('Preferences', {'fields': ('notification_preferences', 'email_notifications', 'language', 'profile_picture')}),
        ('Important dates', {'fields': ('last_login', 'date_joined')}),
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('email', 'full_name', 'password', 'password2', 'role', 'blood_group'),
        }),
    )
