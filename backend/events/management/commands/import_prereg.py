"""
Management command to bulk-import pre-registered teams and members from a CSV file.

CSV format (with header row):
    team_id,team_name,team_color,member_name,college

Usage:
    python manage.py import_prereg path/to/members.csv

Example CSV:
    team_id,team_name,team_color,member_name,college
    team_phoenix,Team Phoenix,#FF6B6B,Rahul Kumar,MRU
    team_phoenix,Team Phoenix,#FF6B6B,Priya Sharma,MRU
    team_titan,Team Titan,#448AFF,Amit Patel,IIT Delhi
"""

import csv
import os
from django.core.management.base import BaseCommand, CommandError
from events.models import Team, PreRegisteredMember


class Command(BaseCommand):
    help = 'Bulk-import pre-registered teams and members from a CSV file.'

    def add_arguments(self, parser):
        parser.add_argument(
            'csv_file',
            type=str,
            help='Path to the CSV file to import.',
        )
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Validate and preview without saving to the database.',
        )

    def handle(self, *args, **options):
        csv_path = options['csv_file']
        dry_run = options['dry_run']

        if not os.path.exists(csv_path):
            raise CommandError(f'File not found: {csv_path}')

        teams_created = 0
        members_created = 0
        skipped = 0
        errors = []

        with open(csv_path, newline='', encoding='utf-8') as f:
            reader = csv.DictReader(f)

            required_fields = {'team_id', 'team_name', 'team_color', 'member_name', 'college'}
            if not required_fields.issubset(set(reader.fieldnames or [])):
                raise CommandError(
                    f'CSV must have columns: {", ".join(sorted(required_fields))}. '
                    f'Got: {", ".join(reader.fieldnames or [])}'
                )

            for line_num, row in enumerate(reader, start=2):  # start=2 to account for header
                team_id = row['team_id'].strip()
                team_name = row['team_name'].strip()
                team_color = row['team_color'].strip() or '#00E676'
                member_name = row['member_name'].strip()
                college = row['college'].strip()

                if not team_id or not team_name or not member_name or not college:
                    errors.append(f'Line {line_num}: Missing required fields — skipping.')
                    skipped += 1
                    continue

                if dry_run:
                    self.stdout.write(
                        f'[DRY RUN] Line {line_num}: Team="{team_name}" ({team_id}), '
                        f'Member="{member_name}", College="{college}"'
                    )
                    continue

                # Get or create the team
                team, team_was_created = Team.objects.get_or_create(
                    team_id=team_id,
                    defaults={'team_name': team_name, 'team_color': team_color},
                )
                if team_was_created:
                    teams_created += 1
                    self.stdout.write(self.style.SUCCESS(f'  Created team: {team_name} ({team_id})'))

                # Create the pre-registered member slot (idempotent)
                _, member_was_created = PreRegisteredMember.objects.get_or_create(
                    team=team,
                    name=member_name,
                    defaults={'college': college},
                )
                if member_was_created:
                    members_created += 1
                    self.stdout.write(f'    Added member: {member_name} ({college})')
                else:
                    skipped += 1
                    self.stdout.write(
                        self.style.WARNING(f'    Skipped (already exists): {member_name}')
                    )

        # Summary
        if errors:
            self.stderr.write('\nErrors encountered:')
            for err in errors:
                self.stderr.write(f'  {err}')

        if dry_run:
            self.stdout.write(self.style.WARNING('\n[DRY RUN] No changes saved.'))
        else:
            self.stdout.write(
                self.style.SUCCESS(
                    f'\nImport complete: {teams_created} team(s) created, '
                    f'{members_created} member slot(s) added, {skipped} skipped.'
                )
            )
