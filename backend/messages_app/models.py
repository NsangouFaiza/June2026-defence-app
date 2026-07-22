from django.db import models
from django.conf import settings


class UserPresence(models.Model):
    """Track online status for chat participants."""

    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='presence')
    is_online = models.BooleanField(default=False)
    last_seen = models.DateTimeField(auto_now=True)

    def __str__(self):
        status = 'online' if self.is_online else 'offline'
        return f'{self.user.email} ({status})'


class Conversation(models.Model):
    participants = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name='conversations')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self):
        return f"Conversation {self.id}"


class Message(models.Model):
    MESSAGE_TYPES = (
        ('text', 'Text'),
        ('voice', 'Voice'),
    )
    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name='messages')
    sender = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='sent_messages')
    content = models.TextField(blank=True, default='')
    attachment = models.FileField(upload_to='voice_messages/', null=True, blank=True)
    message_type = models.CharField(max_length=20, choices=MESSAGE_TYPES, default='text')
    voice_duration = models.IntegerField(default=0)
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['conversation', 'created_at']),
            models.Index(fields=['sender']),
        ]

    def __str__(self):
        return f"{self.sender.email} - {self.created_at}"
