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
        help_text="NFC tag hardware UID in uppercase hex without colons"
    )
    name = models.CharField(max_length=200)
    college = models.CharField(max_length=200)
    
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
