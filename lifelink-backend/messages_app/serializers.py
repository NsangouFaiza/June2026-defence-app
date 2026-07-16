from rest_framework import serializers
from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_email = serializers.EmailField(source='sender.email', read_only=True)

    class Meta:
        model = Message
        fields = ['id', 'conversation', 'sender', 'sender_email', 'content', 'attachment', 'is_read', 'read_at', 'created_at']
        read_only_fields = ['created_at']


class ConversationSerializer(serializers.ModelSerializer):
    last_message = serializers.SerializerMethodField()
    participants_emails = serializers.SerializerMethodField()
    participant1 = serializers.SerializerMethodField()
    participant1_name = serializers.SerializerMethodField()
    participant2 = serializers.SerializerMethodField()
    participant2_name = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            'id', 'participants', 'participants_emails', 'last_message', 
            'created_at', 'updated_at', 'participant1', 'participant1_name', 
            'participant2', 'participant2_name'
        ]
        read_only_fields = ['created_at', 'updated_at']

    def get_last_message(self, obj):
        last = obj.messages.last()
        if last:
            return MessageSerializer(last).data
        return None

    def get_participants_emails(self, obj):
        return [p.email for p in obj.participants.all()]

    def get_participant1(self, obj):
        parts = list(obj.participants.all())
        return parts[0].id if len(parts) > 0 else 0

    def get_participant1_name(self, obj):
        parts = list(obj.participants.all())
        return parts[0].full_name if len(parts) > 0 else 'Unknown'

    def get_participant2(self, obj):
        parts = list(obj.participants.all())
        return parts[1].id if len(parts) > 1 else 0

    def get_participant2_name(self, obj):
        parts = list(obj.participants.all())
        return parts[1].full_name if len(parts) > 1 else 'Unknown'
