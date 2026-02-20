from rest_framework import serializers
from .models import Participant


class ParticipantSerializer(serializers.ModelSerializer):
    """Serializer for participant info returned after NFC scan."""

    class Meta:
        model = Participant
        fields = [
            'uid', 'name', 'college',
            'breakfast', 'lunch', 'dinner', 'goodie_collected',
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


class LoginRequestSerializer(serializers.Serializer):
    """Validates admin login credentials."""
    username = serializers.CharField(max_length=150)
    password = serializers.CharField(max_length=128)
