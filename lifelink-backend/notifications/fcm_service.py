"""
Firebase Cloud Messaging stub for push notifications.

Configure FIREBASE_CREDENTIALS_PATH in backend/.env and call
`initialize_firebase()` during Django startup for production use.
"""

from __future__ import annotations

import logging
from typing import Any

from decouple import config

logger = logging.getLogger(__name__)


def initialize_firebase() -> bool:
    """Initialize Firebase Admin SDK when credentials are available."""
    credentials_path = config('FIREBASE_CREDENTIALS_PATH', default='')
    if not credentials_path:
        logger.info('Firebase not configured; push notifications run in stub mode')
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        if not firebase_admin._apps:
            cred = credentials.Certificate(credentials_path)
            firebase_admin.initialize_app(cred)
        return True
    except Exception as exc:
        logger.warning('Firebase initialization failed: %s', exc)
        return False


def send_push_notification(
    device_token: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Send a push notification via FCM or return a stub response."""
    if not initialize_firebase():
        logger.info('Stub push -> token=%s title=%s body=%s', device_token[:8], title, body)
        return {
            'success': True,
            'mode': 'stub',
            'message_id': f'stub-{device_token[:8]}',
            'title': title,
            'body': body,
            'data': data or {},
        }

    from firebase_admin import messaging

    message = messaging.Message(
        notification=messaging.Notification(title=title, body=body),
        data={k: str(v) for k, v in (data or {}).items()},
        token=device_token,
    )
    message_id = messaging.send(message)
    return {'success': True, 'mode': 'live', 'message_id': message_id}
