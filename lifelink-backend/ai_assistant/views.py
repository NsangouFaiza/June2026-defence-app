import logging
from rest_framework import status, permissions
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from .ai_service import ai_service

logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def ai_chat_view(request):
    """
    POST /api/ai/chat/
    Body:
    {
        "message": "Can I donate if I had malaria?",
        "role": "donor",
        "history": [{"isUser": true, "text": "Hi"}]
    }
    """
    message = request.data.get('message', '').strip()
    if not message:
        return Response(
            {'status': 'error', 'detail': 'Message cannot be empty.'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Determine user role and name from authenticated user or request payload
    role = request.data.get('role')
    user_name = ''
    if request.user and request.user.is_authenticated:
        if not role:
            role = getattr(request.user, 'role', 'donor')
        user_name = getattr(request.user, 'full_name', getattr(request.user, 'username', ''))
    
    if not role:
        role = 'donor'

    history = request.data.get('history', [])

    try:
        response_data = ai_service.get_response(
            user_message=message,
            role=role,
            user_name=user_name,
            history=history
        )
        return Response(response_data, status=status.HTTP_200_OK)
    except Exception as e:
        logger.exception(f"Error in ai_chat_view: {e}")
        # Return graceful fallback error response
        return Response(
            {
                'status': 'fallback',
                'reply': (
                    "I am currently experiencing a temporary connection glitch with the AI service. "
                    "However, for urgent blood requests, please navigate to your dashboard and select "
                    "'Emergency Request'. For blood donation eligibility questions, please visit the "
                    "'Eligibility Check' screen."
                ),
                'role': role,
                'suggestions': ai_service.get_suggestions_for_role(role)
            },
            status=status.HTTP_200_OK
        )


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def ai_suggestions_view(request):
    """
    GET /api/ai/suggestions/?role=donor
    """
    role = request.query_params.get('role')
    if not role and request.user and request.user.is_authenticated:
        role = getattr(request.user, 'role', 'donor')
    
    if not role:
        role = 'donor'

    suggestions = ai_service.get_suggestions_for_role(role)
    return Response({'role': role, 'suggestions': suggestions}, status=status.HTTP_200_OK)
