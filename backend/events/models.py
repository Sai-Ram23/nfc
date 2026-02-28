from django.db import models


class Team(models.Model):
    """
    Represents a team of participants at the event.
    """
    team_id = models.CharField(max_length=50, unique=True, db_index=True)
    team_name = models.CharField(max_length=100)
    team_color = models.CharField(
        max_length=7,
        default='#00E676',
        help_text="Hex color code for team identification"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['team_name']
        verbose_name = "Team"
        verbose_name_plural = "Teams"

    def __str__(self):
        return self.team_name


class PreRegisteredMember(models.Model):
    """
    A pre-loaded participant slot linked to a team but not yet assigned an NFC UID.
    Created by admin (via CSV import or mobile app) before the event starts.
    Once a blank NFC card is tapped and linked at registration, a Participant is
    created from this slot and is_linked is set to True.
    """
    team = models.ForeignKey(
        Team,
        on_delete=models.CASCADE,
        related_name='pre_registered',
    )
    name = models.CharField(max_length=200)
    college = models.CharField(max_length=200)
    is_linked = models.BooleanField(
        default=False,
        help_text="True once an NFC UID has been assigned to this slot."
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        unique_together = [('team', 'name')]  # No duplicate names within the same team
        verbose_name = "Pre-Registered Member"
        verbose_name_plural = "Pre-Registered Members"

    def __str__(self):
        status = "linked" if self.is_linked else "unlinked"
        return f"{self.name} ({self.team.team_name}) [{status}]"


class Participant(models.Model):
    """
    Represents an event participant identified by their NFC tag UID.
    Tracks food and goodie distribution status.
    """
    uid = models.CharField(
        max_length=32,
        unique=True,
        db_index=True,
        help_text="NFC tag hardware UID in uppercase hex without colons"
    )
    name = models.CharField(max_length=200)
    college = models.CharField(max_length=200)

    # Team association (nullable for solo participants)
    team = models.ForeignKey(
        Team,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='members',
    )

    # Distribution Status
    registration_goodies = models.BooleanField(default=False)
    registration_time = models.DateTimeField(null=True, blank=True)

    breakfast = models.BooleanField(default=False)
    breakfast_time = models.DateTimeField(null=True, blank=True)

    lunch = models.BooleanField(default=False)
    lunch_time = models.DateTimeField(null=True, blank=True)

    snacks = models.BooleanField(default=False)
    snacks_time = models.DateTimeField(null=True, blank=True)

    dinner = models.BooleanField(default=False)
    dinner_time = models.DateTimeField(null=True, blank=True)

    midnight_snacks = models.BooleanField(default=False)
    midnight_snacks_time = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Participant"
        verbose_name_plural = "Participants"

    def __str__(self):
        return f"{self.name} ({self.uid})"

    @property
    def team_size(self):
        """Returns the number of members in this participant's team, or 1 if solo."""
        if self.team:
            return self.team.members.count()
        return 1

    @property
    def team_name_display(self):
        """Returns the team name or 'Individual' for solo participants."""
        return self.team.team_name if self.team else "Individual"
