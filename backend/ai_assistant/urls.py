from django.urls import path
from . import views

urlpatterns = [
    path('chat/', views.ai_chat_view, name='ai_chat'),
    path('suggestions/', views.ai_suggestions_view, name='ai_suggestions'),
]
