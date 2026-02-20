from django.urls import path
from . import views

urlpatterns = [
    path('scan/', views.scan_uid, name='scan-uid'),
    path('give-breakfast/', views.give_breakfast, name='give-breakfast'),
    path('give-lunch/', views.give_lunch, name='give-lunch'),
    path('give-dinner/', views.give_dinner, name='give-dinner'),
    path('give-goodie/', views.give_goodie, name='give-goodie'),
    path('login/', views.admin_login, name='admin-login'),
    path('stats/', views.dashboard_stats, name='dashboard-stats'),
]
