from django.contrib import admin
from .models import Participant


@admin.register(Participant)
class ParticipantAdmin(admin.ModelAdmin):
    list_display = [
        'uid', 'name', 'college',
        'registration_goodies', 'breakfast', 'lunch', 
        'snacks', 'dinner', 'midnight_snacks',
        'created_at',
    ]
    list_filter = [
        'registration_goodies', 'breakfast', 'lunch', 
        'snacks', 'dinner', 'midnight_snacks', 
        'college'
    ]
    search_fields = ['uid', 'name', 'college']
    readonly_fields = [
        'registration_time', 'breakfast_time', 'lunch_time', 
        'snacks_time', 'dinner_time', 'midnight_snacks_time', 
        'created_at'
    ]
    list_per_page = 50
