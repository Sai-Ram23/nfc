from django.contrib import admin
from .models import Team, Participant, PreRegisteredMember


@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ['team_id', 'team_name', 'team_color', 'member_count', 'created_at']
    search_fields = ['team_id', 'team_name']
    list_per_page = 50

    def member_count(self, obj):
        return obj.members.count()
    member_count.short_description = 'Members'


@admin.register(Participant)
class ParticipantAdmin(admin.ModelAdmin):
    list_display = [
        'uid', 'name', 'college', 'get_team_name',
        'registration_goodies', 'breakfast', 'lunch',
        'snacks', 'dinner', 'midnight_snacks',
        'created_at',
    ]
    list_filter = [
        'registration_goodies', 'breakfast', 'lunch',
        'snacks', 'dinner', 'midnight_snacks',
        'college', 'team',
    ]
    search_fields = ['uid', 'name', 'college', 'team__team_name']
    readonly_fields = [
        'registration_time', 'breakfast_time', 'lunch_time',
        'snacks_time', 'dinner_time', 'midnight_snacks_time',
        'created_at',
    ]
    list_per_page = 50
    raw_id_fields = ['team']

    def get_team_name(self, obj):
        return obj.team_name_display
    get_team_name.short_description = 'Team'
    get_team_name.admin_order_field = 'team__team_name'


@admin.register(PreRegisteredMember)
class PreRegisteredMemberAdmin(admin.ModelAdmin):
    list_display = ['name', 'college', 'team', 'is_linked', 'created_at']
    list_filter = ['is_linked', 'team']
    search_fields = ['name', 'college', 'team__team_name']
    list_per_page = 50
    raw_id_fields = ['team']
