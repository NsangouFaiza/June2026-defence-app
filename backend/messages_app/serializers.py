from rest_framework import serializers
from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    sender_email = serializers.EmailField(source='sender.email', read_only=True)
    sender_name = serializers.CharField(source='sender.full_name', read_only=True)
    sender_donor_level = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            'id', 'conversation', 'sender', 'sender_email', 'sender_name',
            'content', 'attachment', 'message_type', 'voice_duration',
            'is_read', 'read_at', 'created_at', 'sender_donor_level'
        ]
        read_only_fields = ['created_at']

    def get_sender_donor_level(self, obj):
        if obj.sender.role == 'donor' and hasattr(obj.sender, 'donor_profile'):
            return obj.sender.donor_profile.level
        return None


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
        try:
            last = obj.messages.order_by('created_at').last()
            if last:
                return MessageSerializer(last, context=self.context).data
        except Exception:
            pass
        return None

    def get_participants_emails(self, obj):
        try:
            return [p.email for p in obj.participants.all()]
        except Exception:
            return []

    def get_participant1(self, obj):
        try:
            parts = list(obj.participants.all())
            return parts[0].id if len(parts) > 0 else 0
        except Exception:
            return 0

    def get_participant1_name(self, obj):
        try:
            parts = list(obj.participants.all())
            return parts[0].full_name if len(parts) > 0 else 'Unknown'
        except Exception:
            return 'Unknown'

    def get_participant2(self, obj):
        try:
            parts = list(obj.participants.all())
            return parts[1].id if len(parts) > 1 else (parts[0].id if len(parts) > 0 else 0)
        except Exception:
            return 0

    def get_participant2_name(self, obj):
        try:
            parts = list(obj.participants.all())
            return parts[1].full_name if len(parts) > 1 else (parts[0].full_name if len(parts) > 0 else 'Unknown')
        except Exception:
            return 'Unknown'
