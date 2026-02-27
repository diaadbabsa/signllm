from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import LoginSerializer, UserSerializer


@api_view(['POST'])
@permission_classes([AllowAny])
def login_view(request):
    """
    POST /api/auth/login/
    Body: { "username": "...", "password": "..." }
    Returns: { "access", "refresh", "user": { ... } }
    """
    serializer = LoginSerializer(data=request.data)

    if not serializer.is_valid():
        errors = serializer.errors
        # Flatten non_field_errors for cleaner mobile display
        if 'non_field_errors' in errors:
            return Response(
                {'error': errors['non_field_errors'][0]},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        return Response(
            {'error': 'بيانات غير صالحة', 'details': errors},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = serializer.validated_data['user']
    refresh = RefreshToken.for_user(user)

    return Response({
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'user': UserSerializer(user).data,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def me_view(request):
    """
    GET /api/auth/me/
    Returns current user profile.
    """
    return Response(UserSerializer(request.user).data)
