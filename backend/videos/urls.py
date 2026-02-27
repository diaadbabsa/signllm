from django.urls import path
from . import views

urlpatterns = [
    path('analyze/', views.analyze_view, name='video_analyze'),
]

admin_panel_urlpatterns = [
    path('', views.avatar_list, name='avatar_list'),
    path('upload/', views.avatar_upload, name='avatar_upload'),
    path('<int:pk>/delete/', views.avatar_delete, name='avatar_delete'),
]
