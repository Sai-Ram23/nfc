from django.contrib import admin
from .models import Participant


@admin.register(Participant)
class ParticipantAdmin(admin.ModelAdmin):
    list_display = [
        'uid', 'name', 'college',
        'breakfast', 'lunch', 'dinner', 'goodie_collected',
        'created_at',
    ]
    list_filter = ['breakfast', 'lunch', 'dinner', 'goodie_collected', 'college']
    search_fields = ['uid', 'name', 'college']
    readonly_fields = ['created_at']
    list_per_page = 50
