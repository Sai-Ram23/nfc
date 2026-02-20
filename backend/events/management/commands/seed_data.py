import random
from django.core.management.base import BaseCommand
from django.contrib.auth.models import User
from rest_framework.authtoken.models import Token
from events.models import Participant


# Sample data for realistic participants
FIRST_NAMES = [
    'Rahul', 'Priya', 'Arun', 'Sneha', 'Vikram',
    'Deepa', 'Karthik', 'Ananya', 'Suresh', 'Divya',
    'Manoj', 'Kavitha', 'Rajesh', 'Meena', 'Arjun',
    'Lakshmi', 'Ganesh', 'Swathi', 'Prasad', 'Nandini',
]

LAST_NAMES = [
    'Kumar', 'Sharma', 'Reddy', 'Patel', 'Nair',
    'Iyer', 'Rao', 'Menon', 'Das', 'Pillai',
    'Singh', 'Gupta', 'Joshi', 'Verma', 'Bhat',
    'Shetty', 'Patil', 'Desai', 'Naidu', 'Khanna',
]

COLLEGES = [
    'IIT Madras', 'NIT Trichy', 'VIT Vellore',
    'SRM University', 'Anna University', 'BITS Pilani',
    'PSG Tech Coimbatore', 'SSN College', 'CEG Guindy',
    'Amrita University',
]


def generate_uid():
    """Generate a realistic 7-byte NFC UID as uppercase hex."""
    return ''.join(f'{random.randint(0, 255):02X}' for _ in range(7))


class Command(BaseCommand):
    help = 'Seed the database with sample participants and an admin user.'

    def add_arguments(self, parser):
        parser.add_argument(
            '--count',
            type=int,
            default=20,
            help='Number of participants to create (default: 20)',
        )

    def handle(self, *args, **options):
        count = options['count']

        # Create admin user if not exists
        admin_user, created = User.objects.get_or_create(
            username='admin',
            defaults={
                'email': 'admin@nfcevent.com',
                'is_staff': True,
                'is_superuser': True,
            }
        )
        if created:
            admin_user.set_password('admin123')
            admin_user.save()
            self.stdout.write(self.style.SUCCESS(
                'Created admin user: admin / admin123'
            ))
        else:
            self.stdout.write(self.style.WARNING(
                'Admin user already exists.'
            ))

        # Create auth token for admin
        token, _ = Token.objects.get_or_create(user=admin_user)
        self.stdout.write(self.style.SUCCESS(
            f'Admin auth token: {token.key}'
        ))

        # Create counter user (for food distribution counters)
        counter_user, created = User.objects.get_or_create(
            username='counter1',
            defaults={
                'email': 'counter1@nfcevent.com',
                'is_staff': False,
            }
        )
        if created:
            counter_user.set_password('counter123')
            counter_user.save()
            self.stdout.write(self.style.SUCCESS(
                'Created counter user: counter1 / counter123'
            ))

        counter_token, _ = Token.objects.get_or_create(user=counter_user)
        self.stdout.write(self.style.SUCCESS(
            f'Counter auth token: {counter_token.key}'
        ))

        # Create sample participants
        existing = Participant.objects.count()
        created_count = 0

        for i in range(count):
            first = random.choice(FIRST_NAMES)
            last = random.choice(LAST_NAMES)
            name = f'{first} {last}'
            college = random.choice(COLLEGES)
            uid = generate_uid()

            _, was_created = Participant.objects.get_or_create(
                uid=uid,
                defaults={
                    'name': name,
                    'college': college,
                }
            )
            if was_created:
                created_count += 1

        self.stdout.write(self.style.SUCCESS(
            f'Created {created_count} new participants '
            f'(total: {existing + created_count}).'
        ))

        # Print a few sample UIDs for testing
        samples = Participant.objects.all()[:5]
        self.stdout.write('\nSample participants for testing:')
        self.stdout.write('-' * 60)
        for p in samples:
            self.stdout.write(
                f'  UID: {p.uid}  |  {p.name}  |  {p.college}'
            )
        self.stdout.write('-' * 60)
