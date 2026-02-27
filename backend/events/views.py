from django.db import transaction
from django.utils import timezone
from django.contrib.auth import authenticate
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token

from .models import Participant
from .serializers import (
    ParticipantSerializer,
    ScanRequestSerializer,
    DistributeRequestSerializer,
    LoginRequestSerializer,
)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scan_uid(request):
    """
    POST /api/scan/
    Lookup a participant by NFC tag UID.
    Returns participant info and distribution status.
    """
    serializer = ScanRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    uid = serializer.validated_data['uid']

    try:
        participant = Participant.objects.get(uid=uid)
    except Participant.DoesNotExist:
        print(f"\n[!] UNREGISTERED TAG SCANNED. UID: {uid}\n    Copy this UID and add it to the Django Admin panel.\n")
        return Response({
            'status': 'invalid',
            'message': 'No participant found with this NFC tag.',
        }, status=status.HTTP_404_NOT_FOUND)

    return Response({
        'status': 'valid',
        'name': participant.name,
        'college': participant.college,
        'registration_goodies': participant.registration_goodies,
        'registration_time': participant.registration_time,
        'breakfast': participant.breakfast,
        'breakfast_time': participant.breakfast_time,
        'lunch': participant.lunch,
        'lunch_time': participant.lunch_time,
        'snacks': participant.snacks,
        'snacks_time': participant.snacks_time,
        'dinner': participant.dinner,
        'dinner_time': participant.dinner_time,
        'midnight_snacks': participant.midnight_snacks,
        'midnight_snacks_time': participant.midnight_snacks_time,
    })


def _distribute(request, field_name, time_field_name, label):
    """
    Generic distribution handler.
    Uses transaction.atomic + select_for_update to prevent race conditions.
    Returns success or already_collected.
    """
    serializer = DistributeRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    uid = serializer.validated_data['uid']

    try:
        with transaction.atomic():
            participant = (
                Participant.objects
                .select_for_update()
                .get(uid=uid)
            )

            if getattr(participant, field_name):
                return Response({
                    'status': 'already_collected',
                    'message': f'{label} already collected by {participant.name}.',
                    'name': participant.name,
                    'college': participant.college,
                })

            setattr(participant, field_name, True)
            setattr(participant, time_field_name, timezone.now())
            participant.save(update_fields=[field_name, time_field_name])

            return Response({
                'status': 'success',
                'message': f'{label} given to {participant.name}.',
                'name': participant.name,
                'college': participant.college,
            })

    except Participant.DoesNotExist:
        return Response({
            'status': 'invalid',
            'message': 'No participant found with this NFC tag.',
        }, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_registration(request):
    """POST /api/give-registration/"""
    return _distribute(request, 'registration_goodies', 'registration_time', 'Registration & Goodies')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_breakfast(request):
    """POST /api/give-breakfast/"""
    return _distribute(request, 'breakfast', 'breakfast_time', 'Breakfast')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_lunch(request):
    """POST /api/give-lunch/"""
    return _distribute(request, 'lunch', 'lunch_time', 'Lunch')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_snacks(request):
    """POST /api/give-snacks/"""
    return _distribute(request, 'snacks', 'snacks_time', 'Snacks')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_dinner(request):
    """POST /api/give-dinner/"""
    return _distribute(request, 'dinner', 'dinner_time', 'Dinner')


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def give_midnight_snacks(request):
    """POST /api/give-midnight-snacks/"""
    return _distribute(request, 'midnight_snacks', 'midnight_snacks_time', 'Midnight Snacks')


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_login(request):
    """
    POST /api/login/
    Authenticate admin user with username/password.
    Returns auth token on success.
    """
    serializer = LoginRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    user = authenticate(
        username=serializer.validated_data['username'],
        password=serializer.validated_data['password'],
    )

    if user is None:
        return Response({
            'status': 'error',
            'message': 'Invalid credentials.',
        }, status=status.HTTP_401_UNAUTHORIZED)

    token, _ = Token.objects.get_or_create(user=user)

    return Response({
        'status': 'success',
        'token': token.key,
        'username': user.username,
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_stats(request):
    """
    GET /api/stats/
    Returns distribution statistics for the admin dashboard.
    """
    total = Participant.objects.count()
    stats = {
        'total_participants': total,
        'registration_given': Participant.objects.filter(registration_goodies=True).count(),
        'breakfast_given': Participant.objects.filter(breakfast=True).count(),
        'lunch_given': Participant.objects.filter(lunch=True).count(),
        'snacks_given': Participant.objects.filter(snacks=True).count(),
        'dinner_given': Participant.objects.filter(dinner=True).count(),
        'midnight_snacks_given': Participant.objects.filter(midnight_snacks=True).count(),
    }
    return Response(stats)
