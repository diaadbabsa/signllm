from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import User


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ('username', 'full_name', 'role', 'school_name', 'is_active')
    list_filter = ('role', 'is_active', 'school_name')
    search_fields = ('username', 'full_name', 'school_name')

    fieldsets = BaseUserAdmin.fieldsets + (
        ('Sign Vision Info', {
            'fields': ('role', 'full_name', 'school_name'),
        }),
    )

    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Sign Vision Info', {
            'fields': ('role', 'full_name', 'school_name'),
        }),
    )
