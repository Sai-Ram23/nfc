from rest_framework import serializers
from .models import Team, Participant


class TeamSerializer(serializers.ModelSerializer):
    """Serializer for Team info."""
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Team
        fields = ['team_id', 'team_name', 'team_color', 'member_count', 'created_at']
        read_only_fields = fields

    def get_member_count(self, obj):
        return obj.members.count()


class TeamMemberSerializer(serializers.ModelSerializer):
    """Compact serializer for team member listings."""
    items_collected = serializers.SerializerMethodField()
    last_scan = serializers.SerializerMethodField()

    class Meta:
        model = Participant
        fields = [
            'uid', 'name', 'college',
            'registration_goodies', 'breakfast', 'lunch',
            'snacks', 'dinner', 'midnight_snacks',
            'items_collected', 'last_scan',
        ]
        read_only_fields = fields

    def get_items_collected(self, obj):
        count = 0
        for field in ['registration_goodies', 'breakfast', 'lunch', 'snacks', 'dinner', 'midnight_snacks']:
            if getattr(obj, field):
                count += 1
        return count

    def get_last_scan(self, obj):
        timestamps = [
            obj.registration_time, obj.breakfast_time, obj.lunch_time,
            obj.snacks_time, obj.dinner_time, obj.midnight_snacks_time,
        ]
        valid = [t for t in timestamps if t is not None]
        return max(valid).isoformat() if valid else None


class ParticipantSerializer(serializers.ModelSerializer):
    """Serializer for participant info returned after NFC scan."""
    team_id = serializers.CharField(source='team.team_id', default='')
    team_name = serializers.CharField(source='team_name_display')
    team_color = serializers.CharField(source='team.team_color', default='#00E676')
    team_size = serializers.IntegerField()

    class Meta:
        model = Participant
        fields = [
            'uid', 'name', 'college',
            'team_id', 'team_name', 'team_color', 'team_size',
            'registration_goodies', 'registration_time',
            'breakfast', 'breakfast_time',
            'lunch', 'lunch_time',
            'snacks', 'snacks_time',
            'dinner', 'dinner_time',
            'midnight_snacks', 'midnight_snacks_time',
        ]
        read_only_fields = fields


class ScanRequestSerializer(serializers.Serializer):
    """Validates the UID sent from the mobile app on NFC scan."""
    uid = serializers.CharField(max_length=32)

    def validate_uid(self, value):
        return value.upper().replace(':', '').replace('-', '').strip()


class DistributeRequestSerializer(serializers.Serializer):
    """Validates the UID sent for a distribution action."""
    uid = serializers.CharField(max_length=32)

    def validate_uid(self, value):
        return value.upper().replace(':', '').replace('-', '').strip()


class TeamDistributeRequestSerializer(serializers.Serializer):
    """Validates a bulk team distribution request."""
    team_id = serializers.CharField(max_length=50)
    item = serializers.ChoiceField(choices=[
        ('registration_goodies', 'Registration & Goodies'),
        ('breakfast', 'Breakfast'),
        ('lunch', 'Lunch'),
        ('snacks', 'Snacks'),
        ('dinner', 'Dinner'),
        ('midnight_snacks', 'Midnight Snacks'),
    ])


class LoginRequestSerializer(serializers.Serializer):
    """Validates admin login credentials."""
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(max_length=128)


# ---------- Pre-Registration Serializers ----------

class PreRegMemberSerializer(serializers.Serializer):
    """Un-linked pre-registered member slot (no UID yet)."""
    id = serializers.IntegerField()
    name = serializers.CharField()
    college = serializers.CharField()


class PreRegTeamSerializer(serializers.Serializer):
    """Team with its list of unlinked pre-registered member slots."""
    team_id = serializers.CharField()
    team_name = serializers.CharField()
    team_color = serializers.CharField()
    unregistered_members = PreRegMemberSerializer(many=True)


class RegisterNfcRequestSerializer(serializers.Serializer):
    """Request body for linking an NFC UID to a pre-registered member slot."""
    uid = serializers.CharField(max_length=32)
    prereg_member_id = serializers.IntegerField()

    def validate_uid(self, value):
        return value.upper().replace(':', '').replace('-', '').strip()


class CreateTeamSerializer(serializers.Serializer):
    """Request body for creating a new team from the mobile app."""
    team_id = serializers.CharField(max_length=50)
    team_name = serializers.CharField(max_length=100)
    team_color = serializers.CharField(max_length=7, default='#00E676')


class AddMemberSerializer(serializers.Serializer):
    """Request body for adding a single member slot to an existing team."""
    name = serializers.CharField(max_length=200)
    college = serializers.CharField(max_length=200)
