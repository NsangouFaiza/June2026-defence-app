from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.views import APIView
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework import viewsets

from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(generics.ListAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)


class NotificationDetailView(generics.RetrieveAPIView):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user)


class NotificationActionViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """Mark a notification as read."""
        try:
            notification = Notification.objects.get(pk=pk, recipient=request.user)
            notification.is_read = True
            notification.read_at = timezone.now()
            notification.save()
            return Response(NotificationSerializer(notification).data)
        except Notification.DoesNotExist:
            return Response(
                {'error': 'Notification not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        """Mark all notifications as read."""
        Notification.objects.filter(recipient=request.user, is_read=False).update(
            is_read=True, read_at=timezone.now()
        )
        return Response({'message': 'All notifications marked as read'})


class IsStaffOrAdmin(permissions.BasePermission):
    def has_permission(self, request, view):
        return request.user and request.user.is_authenticated and (
            request.user.is_staff
            or request.user.role in ('hospital_staff', 'blood_bank_admin', 'system_admin')
        )


class SendNotificationView(APIView):
    permission_classes = [IsStaffOrAdmin]

    def post(self, request):
        from rest_framework.views import APIView
        recipient_id = request.data.get('recipient_id')
        title = request.data.get('title', '').strip()
        message = request.data.get('message', '').strip()
        notification_type = request.data.get('type', 'SYSTEM')

        if not title or not message:
            return Response(
                {'error': 'Title and message are required'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from users.models import User
        if recipient_id and recipient_id != 'all':
            try:
                recipient = User.objects.get(pk=recipient_id)
                recipients = [recipient]
            except User.DoesNotExist:
                return Response(
                    {'error': f'Recipient user with ID {recipient_id} not found'},
                    status=status.HTTP_404_NOT_FOUND,
                )
        else:
            recipients = User.objects.filter(role='donor')

        if not recipients:
            return Response(
                {'error': 'No recipients found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        from .models import Notification
        notifications = []
        for r in recipients:
            n = Notification.objects.create(
                recipient=r,
                notification_type=notification_type,
                title=title,
                message=message,
            )
            notifications.append(n)

        try:
            from .fcm_service import send_push_notification
            for n in notifications:
                send_push_notification(n.recipient, n.title, n.message)
        except Exception as e:
            print("FCM Push error:", e, flush=True)

        return Response(
            {'message': f'Notification successfully sent to {len(notifications)} user(s)'},
            status=status.HTTP_201_CREATED,
        )
