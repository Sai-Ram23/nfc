from django.urls import path
from . import views

urlpatterns = [
    path('login/', views.admin_login, name='api-login'),
    path('scan/', views.scan_uid, name='api-scan'),
    path('give-registration/', views.give_registration, name='api-give-registration'),
    path('give-breakfast/', views.give_breakfast, name='api-give-breakfast'),
    path('give-lunch/', views.give_lunch, name='api-give-lunch'),
    path('give-snacks/', views.give_snacks, name='api-give-snacks'),
    path('give-dinner/', views.give_dinner, name='api-give-dinner'),
    path('give-midnight-snacks/', views.give_midnight_snacks, name='api-give-midnight-snacks'),
    path('stats/', views.dashboard_stats, name='api-stats'),
    # Team endpoints
    path('team/<str:team_id>/', views.team_details, name='api-team-details'),
    path('distribute-team/', views.distribute_team, name='api-distribute-team'),
    path('teams/stats/', views.teams_stats, name='api-teams-stats'),
    path('attendees/', views.attendees_list, name='api-attendees'),
]
