from django.db import models


class Participant(models.Model):
    """
    Represents an event participant identified by their NFC tag UID.
    Tracks food and goodie distribution status.
    """
    uid = models.CharField(
        max_length=32,
        unique=True,
        db_index=True,
        help_text="NFC tag hardware UID (uppercase hex, no colons)"
    )
    name = models.CharField(max_length=200)
    college = models.CharField(max_length=200)
    breakfast = models.BooleanField(default=False)
    lunch = models.BooleanField(default=False)
    dinner = models.BooleanField(default=False)
    goodie_collected = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['name']
        verbose_name = 'Participant'
        verbose_name_plural = 'Participants'

    def __str__(self):
        return f"{self.name} ({self.uid})"
