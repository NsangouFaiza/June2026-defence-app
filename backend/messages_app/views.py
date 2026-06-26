from django.db.models import Q
from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import serializers

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer


class ConversationViewSet(viewsets.ModelViewSet):
    """ViewSet for Conversation model."""

    queryset = Conversation.objects.all()
    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Conversation.objects.filter(participants=self.request.user)

    def create(self, request, *args, **kwargs):
        other_user_id = request.data.get('other_user_id') or request.query_params.get('other_user_id')
        if other_user_id:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            try:
                other_user = User.objects.get(pk=other_user_id)
            except User.DoesNotExist:
                return Response({'error': 'Other user does not exist'}, status=status.HTTP_404_NOT_FOUND)
                
            existing = Conversation.objects.filter(participants=request.user).filter(participants=other_user).first()
            if existing:
                serializer = self.get_serializer(existing)
                return Response(serializer.data)
                
            conversation = Conversation.objects.create()
            conversation.participants.add(request.user, other_user)
            serializer = self.get_serializer(conversation)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        return super().create(request, *args, **kwargs)

    @action(detail=False, methods=['get'])
    def list_conversations(self, request):
        """List current user's conversations."""
        conversations = Conversation.objects.filter(participants=request.user)
        serializer = self.get_serializer(conversations, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get', 'post'])
    def messages(self, request, pk=None):
        """Get or send messages inside a specific conversation."""
        conversation = self.get_object()
        if request.method == 'POST':
            content = request.data.get('content')
            attachment = request.data.get('attachment')
            if not content:
                return Response({'error': 'content is required'}, status=status.HTTP_400_BAD_REQUEST)
                
            message = Message.objects.create(
                conversation=conversation,
                sender=request.user,
                content=content,
                attachment=attachment,
            )
            conversation.save()
            serializer = MessageSerializer(message)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
            
        # GET method
        messages = conversation.messages.all().order_by('created_at')
        serializer = MessageSerializer(messages, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], url_path='mark-read')
    def mark_read(self, request, pk=None):
        """Mark incoming messages in the conversation as read."""
        conversation = self.get_object()
        from django.utils import timezone
        unread = conversation.messages.filter(is_read=False).exclude(sender=request.user)
        count = unread.count()
        unread.update(is_read=True, read_at=timezone.now())
        return Response({'status': 'messages marked as read', 'count': count})


class MessageViewSet(viewsets.ModelViewSet):
    """ViewSet for Message model."""

    queryset = Message.objects.all()
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        conversation_id = self.request.query_params.get('conversation_id')
        if conversation_id:
            return Message.objects.filter(
                conversation_id=conversation_id,
                conversation__participants=self.request.user,
            ).order_by('created_at')
        return Message.objects.filter(conversation__participants=self.request.user)

    def perform_create(self, serializer):
        conversation_id = self.request.data.get('conversation_id')
        if not conversation_id:
            raise serializers.ValidationError('conversation_id is required')
        conversation = Conversation.objects.get(pk=conversation_id, participants=self.request.user)
        serializer.save(sender=self.request.user, conversation=conversation)
