from django.db import transaction
from django.db.models import Q
from django.utils import timezone
from django.contrib.auth import authenticate
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token

from .models import Team, Participant
from .serializers import (
    ParticipantSerializer,
    TeamMemberSerializer,
    ScanRequestSerializer,
    DistributeRequestSerializer,
    TeamDistributeRequestSerializer,
    LoginRequestSerializer,
)

# ---------- Item field mapping ----------
ITEM_FIELDS = {
    'registration_goodies': ('registration_goodies', 'registration_time', 'Registration & Goodies'),
    'breakfast':            ('breakfast',            'breakfast_time',     'Breakfast'),
    'lunch':                ('lunch',                'lunch_time',         'Lunch'),
    'snacks':               ('snacks',               'snacks_time',        'Snacks'),
    'dinner':               ('dinner',               'dinner_time',        'Dinner'),
    'midnight_snacks':      ('midnight_snacks',      'midnight_snacks_time', 'Midnight Snacks'),
}


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def scan_uid(request):
    """
    POST /api/scan/
    Lookup a participant by NFC tag UID.
    Returns participant info, distribution status, and team info.
    """
    serializer = ScanRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    uid = serializer.validated_data['uid']

    try:
        participant = Participant.objects.select_related('team').get(uid=uid)
    except Participant.DoesNotExist:
        print(f"\n[!] UNREGISTERED TAG SCANNED. UID: {uid}\n    Copy this UID and add it to the Django Admin panel.\n")
        return Response({
            'status': 'invalid',
            'message': 'No participant found with this NFC tag.',
        }, status=status.HTTP_404_NOT_FOUND)

    return Response({
        'status': 'valid',
        'uid': participant.uid,
        'name': participant.name,
        'college': participant.college,
        'team_id': participant.team.team_id if participant.team else '',
        'team_name': participant.team_name_display,
        'team_color': participant.team.team_color if participant.team else '#00E676',
        'team_size': participant.team_size,
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
    Includes team-related stats.
    """
    total = Participant.objects.count()
    total_teams = Team.objects.count()
    solo_count = Participant.objects.filter(team__isnull=True).count()
    team_members_count = total - solo_count

    stats = {
        'total_participants': total,
        'total_teams': total_teams,
        'solo_participants': solo_count,
        'average_team_size': round(team_members_count / total_teams, 1) if total_teams > 0 else 0,
        'registration_given': Participant.objects.filter(registration_goodies=True).count(),
        'breakfast_given': Participant.objects.filter(breakfast=True).count(),
        'lunch_given': Participant.objects.filter(lunch=True).count(),
        'snacks_given': Participant.objects.filter(snacks=True).count(),
        'dinner_given': Participant.objects.filter(dinner=True).count(),
        'midnight_snacks_given': Participant.objects.filter(midnight_snacks=True).count(),
    }
    return Response(stats)


# ---------- NEW TEAM ENDPOINTS ----------


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def team_details(request, team_id):
    """
    GET /api/team/<team_id>/
    Returns detailed team info: members list and per-item collection progress.
    """
    try:
        team = Team.objects.get(team_id=team_id)
    except Team.DoesNotExist:
        return Response({
            'status': 'error',
            'message': 'Team not found.',
        }, status=status.HTTP_404_NOT_FOUND)

    members = team.members.all()
    member_count = members.count()

    # Calculate per-item team progress
    team_progress = {}
    for item_key, (field, _, label) in ITEM_FIELDS.items():
        collected = members.filter(**{field: True}).count()
        team_progress[item_key] = f"{collected}/{member_count}"

    return Response({
        'team_id': team.team_id,
        'team_name': team.team_name,
        'team_color': team.team_color,
        'member_count': member_count,
        'members': TeamMemberSerializer(members, many=True).data,
        'team_progress': team_progress,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def distribute_team(request):
    """
    POST /api/distribute-team/
    Bulk distribute a single item to all uncollected team members.
    Body: { "team_id": "...", "item": "lunch" }
    """
    serializer = TeamDistributeRequestSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    team_id = serializer.validated_data['team_id']
    item = serializer.validated_data['item']

    field_name, time_field_name, label = ITEM_FIELDS[item]

    try:
        team = Team.objects.get(team_id=team_id)
    except Team.DoesNotExist:
        return Response({
            'status': 'error',
            'message': 'Team not found.',
        }, status=status.HTTP_404_NOT_FOUND)

    now = timezone.now()
    distributed = []
    already_collected = []

    with transaction.atomic():
        members = team.members.select_for_update().all()
        for member in members:
            if getattr(member, field_name):
                already_collected.append(member.uid)
            else:
                setattr(member, field_name, True)
                setattr(member, time_field_name, now)
                member.save(update_fields=[field_name, time_field_name])
                distributed.append(member.uid)

    return Response({
        'status': 'success',
        'distributed': distributed,
        'already_collected': already_collected,
        'message': f'{label} distributed to {len(distributed)} team member(s).',
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def teams_stats(request):
    """
    GET /api/teams/stats/
    Returns team-level statistics and leaderboard.
    """
    teams = Team.objects.all()
    total_teams = teams.count()
    solo_count = Participant.objects.filter(team__isnull=True).count()
    team_members_count = Participant.objects.filter(team__isnull=False).count()

    # Build leaderboard: top teams by completion rate
    top_teams = []
    for team in teams:
        members = team.members.all()
        member_count = members.count()
        if member_count == 0:
            continue

        total_items = member_count * 6  # 6 distribution items per member
        collected_items = 0
        for field, _, _ in ITEM_FIELDS.values():
            collected_items += members.filter(**{field: True}).count()

        completion_rate = round((collected_items / total_items) * 100, 1) if total_items > 0 else 0
        top_teams.append({
            'team_id': team.team_id,
            'team_name': team.team_name,
            'team_color': team.team_color,
            'members': member_count,
            'completion_rate': completion_rate,
        })

    # Sort by completion rate descending, take top 10
    top_teams.sort(key=lambda t: t['completion_rate'], reverse=True)

    return Response({
        'total_teams': total_teams,
        'solo_participants': solo_count,
        'average_team_size': round(team_members_count / total_teams, 1) if total_teams > 0 else 0,
        'top_teams': top_teams[:10],
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def attendees_list(request):
    """
    GET /api/attendees/
    Returns all participants with optional search and filtering.
    Query params:
      - search: search by name, uid, team name, or college
      - filter: 'all' | 'solo' | 'team' | 'checked_in' | 'not_checked_in'
      - view: 'individual' | 'team' (team groups results by team)
    """
    queryset = Participant.objects.select_related('team').all()
    search = request.query_params.get('search', '').strip()
    filter_by = request.query_params.get('filter', 'all')
    view_mode = request.query_params.get('view', 'individual')

    # Apply search
    if search:
        queryset = queryset.filter(
            Q(name__icontains=search) |
            Q(uid__icontains=search) |
            Q(college__icontains=search) |
            Q(team__team_name__icontains=search)
        )

    # Apply filters
    if filter_by == 'solo':
        queryset = queryset.filter(team__isnull=True)
    elif filter_by == 'team':
        queryset = queryset.filter(team__isnull=False)
    elif filter_by == 'checked_in':
        queryset = queryset.filter(registration_goodies=True)
    elif filter_by == 'not_checked_in':
        queryset = queryset.filter(registration_goodies=False)

    if view_mode == 'team':
        # Group by team
        teams_data = []

        # Solo participants group
        solo = queryset.filter(team__isnull=True)
        if solo.exists():
            teams_data.append({
                'team_id': None,
                'team_name': 'Individual Participants',
                'team_color': '#B0B0B0',
                'member_count': solo.count(),
                'members': TeamMemberSerializer(solo, many=True).data,
            })

        # Grouped teams — get distinct teams that have members in the queryset
        team_pks = set(
            queryset.filter(team__isnull=False)
            .values_list('team', flat=True)
        )
        for team in Team.objects.filter(pk__in=team_pks):
            members = queryset.filter(team=team)
            teams_data.append({
                'team_id': team.team_id,
                'team_name': team.team_name,
                'team_color': team.team_color,
                'member_count': members.count(),
                'members': TeamMemberSerializer(members, many=True).data,
            })

        return Response({'view': 'team', 'teams': teams_data})
    else:
        # Individual view
        from .serializers import ParticipantSerializer
        data = ParticipantSerializer(queryset, many=True).data
        return Response({'view': 'individual', 'attendees': data})
