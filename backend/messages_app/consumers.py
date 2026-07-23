import json
from datetime import datetime, timezone

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncWebsocketConsumer
from django.contrib.auth import get_user_model
from django.contrib.auth.models import AnonymousUser

from .models import Conversation, Message, UserPresence

User = get_user_model()


class ChatConsumer(AsyncWebsocketConsumer):
    """Real-time chat with read receipts and online status."""

    async def connect(self):
        self.user = self.scope.get('user')
        if not self.user or isinstance(self.user, AnonymousUser) or not self.user.is_authenticated:
            await self.close()
            return

        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'

        if not await self.user_in_conversation(self.user.id, self.conversation_id):
            await self.close()
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.set_presence(self.user.id, True)
        await self.accept()

        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'presence_update',
                'user_id': self.user.id,
                'is_online': True,
            },
        )

    async def disconnect(self, close_code):
        if hasattr(self, 'room_group_name'):
            await self.channel_layer.group_discard(self.room_group_name, self.channel_name)
        if hasattr(self, 'user') and self.user.is_authenticated:
            await self.set_presence(self.user.id, False)
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'presence_update',
                    'user_id': self.user.id,
                    'is_online': False,
                },
            )

    async def receive(self, text_data):
        payload = json.loads(text_data)
        event_type = payload.get('type', 'message')

        if event_type == 'message':
            message_id = payload.get('message_id')
            if message_id:
                # The message was already created (e.g. via HTTP send-voice).
                # Fetch and broadcast it directly.
                message = await self.get_serialized_message(message_id)
                if message:
                    await self.channel_layer.group_send(
                        self.room_group_name,
                        {
                            'type': 'chat_message',
                            'message': message,
                        },
                    )
                return

            content = payload.get('content', '').strip()
            if not content:
                return
            message = await self.create_message(content)
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'message': message,
                },
            )
        elif event_type == 'read_receipt':
            message_id = payload.get('message_id')
            if message_id:
                await self.mark_read(message_id)
                await self.channel_layer.group_send(
                    self.room_group_name,
                    {
                        'type': 'read_receipt',
                        'message_id': message_id,
                        'user_id': self.user.id,
                        'read_at': datetime.now(timezone.utc).isoformat(),
                    },
                )

    async def chat_message(self, event):
        await self.send(text_data=json.dumps({'type': 'message', 'message': event['message']}))

    async def read_receipt(self, event):
        await self.send(text_data=json.dumps({'type': 'read_receipt', **event}))

    async def presence_update(self, event):
        await self.send(text_data=json.dumps({'type': 'presence', **event}))

    @database_sync_to_async
    def user_in_conversation(self, user_id, conversation_id):
        return Conversation.objects.filter(pk=conversation_id, participants__id=user_id).exists()

    @database_sync_to_async
    def get_serialized_message(self, message_id):
        try:
            message = Message.objects.get(pk=message_id)
            # Clear deleted_by status when active in conversation
            message.conversation.deleted_by.clear()
            message.conversation.save()
            return {
                'id': message.id,
                'conversation': message.conversation.id,
                'conversation_id': message.conversation.id,
                'sender': message.sender.id,
                'sender_id': message.sender.id,
                'sender_name': message.sender.full_name,
                'content': message.content,
                'attachment': message.attachment.url if message.attachment else None,
                'message_type': message.message_type,
                'voice_duration': message.voice_duration,
                'is_read': message.is_read,
                'created_at': message.created_at.isoformat(),
                'sender_donor_level': message.sender.donor_profile.level if (message.sender.role == 'donor' and hasattr(message.sender, 'donor_profile')) else None,
            }
        except Message.DoesNotExist:
            return None

    @database_sync_to_async
    def create_message(self, content):
        conversation = Conversation.objects.get(pk=self.conversation_id)
        message = Message.objects.create(
            conversation=conversation,
            sender=self.user,
            content=content,
        )
        conversation.deleted_by.clear()
        conversation.save()
        return {
            'id': message.id,
            'conversation': conversation.id,
            'conversation_id': conversation.id,
            'sender': self.user.id,
            'sender_id': self.user.id,
            'sender_name': self.user.full_name,
            'content': message.content,
            'attachment': message.attachment.url if message.attachment else None,
            'message_type': message.message_type,
            'voice_duration': message.voice_duration,
            'is_read': message.is_read,
            'created_at': message.created_at.isoformat(),
            'sender_donor_level': self.user.donor_profile.level if (self.user.role == 'donor' and hasattr(self.user, 'donor_profile')) else None,
        }

    @database_sync_to_async
    def mark_read(self, message_id):
        Message.objects.filter(
            pk=message_id,
            conversation_id=self.conversation_id,
        ).update(is_read=True, read_at=datetime.now(timezone.utc))

    @database_sync_to_async
    def set_presence(self, user_id, is_online):
        UserPresence.objects.update_or_create(
            user_id=user_id,
            defaults={'is_online': is_online},
        )
