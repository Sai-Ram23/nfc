from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from rest_framework import status
from .models import Team, Participant, PreRegisteredMember


class ScanAPITest(TestCase):
    """Tests for the NFC scan endpoint."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testadmin', password='testpass'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

        self.participant = Participant.objects.create(
            uid='04A23B1C5D6E80',
            name='Rahul Kumar',
            college='IIT Madras',
        )

    def test_scan_valid_uid(self):
        response = self.client.post('/api/scan/', {'uid': '04A23B1C5D6E80'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'valid')
        self.assertEqual(response.data['name'], 'Rahul Kumar')
        self.assertEqual(response.data['college'], 'IIT Madras')
        self.assertFalse(response.data['registration_goodies'])

    def test_scan_invalid_uid(self):
        response = self.client.post('/api/scan/', {'uid': 'INVALID000000'})
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.data['status'], 'unregistered')

    def test_scan_case_insensitive(self):
        """UID should be normalized to uppercase."""
        response = self.client.post('/api/scan/', {'uid': '04a23b1c5d6e80'})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'valid')

    def test_scan_unauthenticated(self):
        self.client.credentials()  # Clear auth
        response = self.client.post('/api/scan/', {'uid': '04A23B1C5D6E80'})
        self.assertEqual(response.status_code, 401)

    def test_scan_solo_returns_individual_team(self):
        """Solo participant should return team_name='Individual', team_size=1."""
        response = self.client.post('/api/scan/', {'uid': '04A23B1C5D6E80'})
        self.assertEqual(response.data['team_name'], 'Individual')
        self.assertEqual(response.data['team_size'], 1)
        self.assertEqual(response.data['team_id'], '')

    def test_scan_with_team_returns_team_info(self):
        """Participant in a team should return team fields."""
        team = Team.objects.create(team_id='team_001', team_name='Team Phoenix', team_color='#FF6B6B')
        self.participant.team = team
        self.participant.save()
        Participant.objects.create(uid='04B23B1C5D6E80', name='Jane Doe', college='IIT Madras', team=team)

        response = self.client.post('/api/scan/', {'uid': '04A23B1C5D6E80'})
        self.assertEqual(response.data['team_id'], 'team_001')
        self.assertEqual(response.data['team_name'], 'Team Phoenix')
        self.assertEqual(response.data['team_color'], '#FF6B6B')
        self.assertEqual(response.data['team_size'], 2)


class DistributionAPITest(TestCase):
    """Tests for distribution endpoints (breakfast, lunch, dinner, goodie)."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testadmin', password='testpass'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

        self.participant = Participant.objects.create(
            uid='04A23B1C5D6E80',
            name='Rahul Kumar',
            college='IIT Madras',
        )

    def test_give_registration_success(self):
        response = self.client.post(
            '/api/give-registration/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.registration_goodies)

    def test_give_registration_duplicate(self):
        self.participant.registration_goodies = True
        self.participant.save()
        response = self.client.post(
            '/api/give-registration/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'already_collected')

    def test_give_breakfast_success(self):
        response = self.client.post(
            '/api/give-breakfast/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.breakfast)

    def test_give_lunch_success(self):
        response = self.client.post(
            '/api/give-lunch/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.lunch)

    def test_give_snacks_success(self):
        response = self.client.post(
            '/api/give-snacks/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.snacks)

    def test_give_dinner_success(self):
        response = self.client.post(
            '/api/give-dinner/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.dinner)

    def test_give_midnight_snacks_success(self):
        response = self.client.post(
            '/api/give-midnight-snacks/', {'uid': '04A23B1C5D6E80'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.participant.refresh_from_db()
        self.assertTrue(self.participant.midnight_snacks)

    def test_distribute_invalid_uid(self):
        response = self.client.post(
            '/api/give-breakfast/', {'uid': 'NONEXISTENT'}
        )
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.data['status'], 'invalid')


class LoginAPITest(TestCase):
    """Tests for the admin login endpoint."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='admin', password='admin123'
        )

    def test_login_success(self):
        response = self.client.post(
            '/api/login/', {'username': 'admin', 'password': 'admin123'}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.assertIn('token', response.data)

    def test_login_invalid(self):
        response = self.client.post(
            '/api/login/', {'username': 'admin', 'password': 'wrong'}
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.data['status'], 'error')


class TeamAPITest(TestCase):
    """Tests for team-specific endpoints."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='testadmin', password='testpass'
        )
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

        # Create a team with 3 members
        self.team = Team.objects.create(
            team_id='team_phoenix',
            team_name='Team Phoenix',
            team_color='#FF6B6B',
        )
        self.member1 = Participant.objects.create(
            uid='AAAA00000001', name='John Doe', college='MRU', team=self.team
        )
        self.member2 = Participant.objects.create(
            uid='AAAA00000002', name='Jane Smith', college='MRU', team=self.team
        )
        self.member3 = Participant.objects.create(
            uid='AAAA00000003', name='Mike Johnson', college='MRU', team=self.team
        )
        # One solo participant
        self.solo = Participant.objects.create(
            uid='BBBB00000001', name='Solo Player', college='IIT',
        )

    def test_team_details(self):
        """GET /api/team/<team_id>/ returns team info and members."""
        response = self.client.get('/api/team/team_phoenix/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['team_id'], 'team_phoenix')
        self.assertEqual(response.data['team_name'], 'Team Phoenix')
        self.assertEqual(response.data['member_count'], 3)
        self.assertEqual(len(response.data['members']), 3)
        # All items uncollected
        self.assertEqual(response.data['team_progress']['lunch'], '0/3')

    def test_team_details_not_found(self):
        response = self.client.get('/api/team/nonexistent/')
        self.assertEqual(response.status_code, 404)

    def test_team_details_progress_after_distribution(self):
        """Progress updates after individual distribution."""
        self.member1.lunch = True
        self.member1.save()
        response = self.client.get('/api/team/team_phoenix/')
        self.assertEqual(response.data['team_progress']['lunch'], '1/3')

    def test_distribute_team_success(self):
        """POST /api/distribute-team/ distributes to all uncollected members."""
        response = self.client.post('/api/distribute-team/', {
            'team_id': 'team_phoenix',
            'item': 'lunch',
        })
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['status'], 'success')
        self.assertEqual(len(response.data['distributed']), 3)
        self.assertEqual(len(response.data['already_collected']), 0)

        # Verify all members received lunch
        for member in [self.member1, self.member2, self.member3]:
            member.refresh_from_db()
            self.assertTrue(member.lunch)

    def test_distribute_team_skips_already_collected(self):
        """Bulk distribution skips members who already collected."""
        self.member1.lunch = True
        self.member1.save()

        response = self.client.post('/api/distribute-team/', {
            'team_id': 'team_phoenix',
            'item': 'lunch',
        })
        self.assertEqual(len(response.data['distributed']), 2)
        self.assertEqual(len(response.data['already_collected']), 1)
        self.assertIn('AAAA00000001', response.data['already_collected'])

    def test_distribute_team_not_found(self):
        response = self.client.post('/api/distribute-team/', {
            'team_id': 'nonexistent',
            'item': 'lunch',
        })
        self.assertEqual(response.status_code, 404)

    def test_distribute_team_invalid_item(self):
        response = self.client.post('/api/distribute-team/', {
            'team_id': 'team_phoenix',
            'item': 'invalid_item',
        })
        self.assertEqual(response.status_code, 400)

    def test_teams_stats(self):
        """GET /api/teams/stats/ returns correct statistics."""
        # Create an empty team to hit the line 330 `continue` check for 0 members
        Team.objects.create(team_id='empty_team', team_name='Empty Team')

        response = self.client.get('/api/teams/stats/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['total_teams'], 2)  # Phoenix + Empty
        self.assertEqual(response.data['solo_participants'], 1)
        self.assertEqual(response.data['average_team_size'], 1.5) # 3 members / 2 teams
        self.assertEqual(len(response.data['top_teams']), 1)
        self.assertEqual(response.data['top_teams'][0]['team_name'], 'Team Phoenix')

    def test_teams_stats_completion_rate(self):
        """Completion rate updates after distribution."""
        # Give member1 all 6 items
        self.member1.registration_goodies = True
        self.member1.breakfast = True
        self.member1.lunch = True
        self.member1.snacks = True
        self.member1.dinner = True
        self.member1.midnight_snacks = True
        self.member1.save()

        response = self.client.get('/api/teams/stats/')
        # 6 out of 18 total items = 33.3%
        self.assertEqual(response.data['top_teams'][0]['completion_rate'], 33.3)

    def test_dashboard_stats_with_teams(self):
        """GET /api/stats/ includes team statistics."""
        response = self.client.get('/api/stats/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['total_participants'], 4)
        self.assertEqual(response.data['total_teams'], 1)
        self.assertEqual(response.data['solo_participants'], 1)
        self.assertEqual(response.data['average_team_size'], 3.0)

    def test_attendees_individual_view(self):
        """GET /api/attendees/?view=individual returns all participants."""
        response = self.client.get('/api/attendees/?view=individual')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['view'], 'individual')
        self.assertEqual(len(response.data['attendees']), 4)

    def test_attendees_team_view(self):
        """GET /api/attendees/?view=team groups by team."""
        response = self.client.get('/api/attendees/?view=team')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['view'], 'team')
        # Should have 2 groups: Individual + Team Phoenix
        self.assertEqual(len(response.data['teams']), 2)

    def test_attendees_search(self):
        """Search filters results by name."""
        response = self.client.get('/api/attendees/?search=John Doe')
        self.assertEqual(len(response.data['attendees']), 1)
        self.assertEqual(response.data['attendees'][0]['name'], 'John Doe')

    def test_attendees_search_by_team_name(self):
        """Search by team name returns all team members."""
        response = self.client.get('/api/attendees/?search=Phoenix')
        self.assertEqual(len(response.data['attendees']), 3)

    def test_attendees_filter_solo(self):
        """Filter solo returns only solo participants."""
        response = self.client.get('/api/attendees/?filter=solo')
        self.assertEqual(len(response.data['attendees']), 1)
        self.assertEqual(response.data['attendees'][0]['name'], 'Solo Player')

    def test_attendees_filter_team(self):
        """Filter team returns only team members."""
        response = self.client.get('/api/attendees/?filter=team')
        self.assertEqual(len(response.data['attendees']), 3)

    def test_attendees_filter_checked_in(self):
        """Filter checked_in returns only participants who have received registration goodies."""
        self.member1.registration_goodies = True
        self.member1.save()
        response = self.client.get('/api/attendees/?filter=checked_in')
        self.assertEqual(len(response.data['attendees']), 1)
        self.assertEqual(response.data['attendees'][0]['name'], 'John Doe')

    def test_attendees_filter_not_checked_in(self):
        """Filter not_checked_in returns only participants who have NOT received registration goodies."""
        self.member1.registration_goodies = True
        self.member1.save()
        response = self.client.get('/api/attendees/?filter=not_checked_in')
        # 4 total participants, 1 checked in, 3 not checked in
        self.assertEqual(len(response.data['attendees']), 3)


class PreRegAPITest(TestCase):
    """Tests for the pre-registration endpoints."""

    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(username='testadmin', password='testpass')
        self.token = Token.objects.create(user=self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f'Token {self.token.key}')

        # Create a team with two pre-registered slots
        self.team = Team.objects.create(
            team_id='team_alpha', team_name='Team Alpha', team_color='#00E676'
        )
        from .models import PreRegisteredMember
        self.slot1 = PreRegisteredMember.objects.create(
            team=self.team, name='Alice', college='MRU'
        )
        self.slot2 = PreRegisteredMember.objects.create(
            team=self.team, name='Bob', college='MRU', is_linked=True
        )

    def test_scan_unregistered_uid(self):
        """Scanning an unknown UID returns status='unregistered' not 'invalid'."""
        response = self.client.post('/api/scan/', {'uid': 'AABBCCDD00'})
        self.assertEqual(response.status_code, 404)
        self.assertEqual(response.data['status'], 'unregistered')
        self.assertIn('uid', response.data)

    def test_prereg_teams_list(self):
        """GET /api/prereg/teams/ returns teams with only unlinked slots."""
        response = self.client.get('/api/prereg/teams/')
        self.assertEqual(response.status_code, 200)
        team_data = next(t for t in response.data if t['team_id'] == 'team_alpha')
        self.assertEqual(len(team_data['unregistered_members']), 1)
        self.assertEqual(team_data['unregistered_members'][0]['name'], 'Alice')

    def test_register_nfc_success(self):
        """POST /api/prereg/register/ creates Participant and marks slot linked."""
        from .models import PreRegisteredMember, Participant
        response = self.client.post('/api/prereg/register/', {
            'uid': 'NEWTAG12345',
            'prereg_member_id': self.slot1.id,
        })
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['status'], 'registered')
        self.assertEqual(response.data['name'], 'Alice')
        self.assertEqual(response.data['team_id'], 'team_alpha')
        self.assertTrue(Participant.objects.filter(uid='NEWTAG12345').exists())
        self.slot1.refresh_from_db()
        self.assertTrue(self.slot1.is_linked)

    def test_register_nfc_tag_invalid_member(self):
        """Test registering with an invalid pre-registered member ID."""
        response = self.client.post('/api/prereg/register/', {
            'uid': '00000000',
            'prereg_member_id': 999
        })
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_add_prereg_member_invalid_team(self):
        """Test adding a member to an invalid team ID."""
        response = self.client.post('/api/prereg/teams/invalid_team_id/add-member/', {
            'name': 'New Student',
            'college': 'Test College'
        })
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_model_str_methods(self):
        """Test that model string representations work correctly."""
        from .models import Team, PreRegisteredMember, Participant
        from .admin import TeamAdmin, ParticipantAdmin
        from .serializers import ParticipantSerializer
        from django.contrib.admin.sites import site
        
        team = Team.objects.create(team_id="code_breakers", team_name="Code Breakers", team_color="#FF0000")
        self.assertEqual(str(team), "Code Breakers")
        
        slot = PreRegisteredMember.objects.create(team=team, name="John Doe", college="Test")
        self.assertEqual(str(slot), "John Doe (Code Breakers) [unlinked]")
        
        participant = Participant.objects.create(
            uid="AB12CD34",
            name="Alice",
            college="Test Univ",
            team=team
        )
        self.assertEqual(str(participant), "Alice (AB12CD34)")

        # Hit admin properties
        team_admin = TeamAdmin(Team, site)
        self.assertEqual(team_admin.member_count(team), 1)

        participant_admin = ParticipantAdmin(Participant, site)
        self.assertEqual(participant_admin.get_team_name(participant), "Code Breakers")
        
        # Hit serializer
        ser = ParticipantSerializer(participant)
        self.assertEqual(ser.data['team_color'], "#FF0000")

    def test_prereg_teams_list_no_unregistered(self):
        """GET /api/prereg/teams/ returns teams even if all slots are linked."""
        # Create a team where all slots are linked
        team_full = Team.objects.create(team_id='team_full', team_name='Team Full', team_color='#ABCDEF')
        PreRegisteredMember.objects.create(team=team_full, name='Member A', college='C1', is_linked=True)
        PreRegisteredMember.objects.create(team=team_full, name='Member B', college='C2', is_linked=True)

        response = self.client.get('/api/prereg/teams/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        team_data = next(t for t in response.data if t['team_id'] == 'team_full')
        self.assertEqual(len(team_data['unregistered_members']), 0)
        self.assertEqual(team_data['team_name'], 'Team Full')

    def test_prereg_teams_list_empty(self):
        """GET /api/prereg/teams/ returns empty list if no teams exist."""
        Team.objects.all().delete() # Clear existing teams
        response = self.client.get('/api/prereg/teams/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data), 0)

    def test_register_duplicate_uid(self):
        """Registering an already-used UID returns 400."""
        from .models import Participant
        Participant.objects.create(uid='EXISTINGTAG', name='Existing', college='MRU')
        response = self.client.post('/api/prereg/register/', {
            'uid': 'EXISTINGTAG',
            'prereg_member_id': self.slot1.id,
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['status'], 'error')

    def test_register_already_linked_slot(self):
        """Linking an already-linked slot returns 400."""
        response = self.client.post('/api/prereg/register/', {
            'uid': 'BRANDNEWTAG',
            'prereg_member_id': self.slot2.id,
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['status'], 'error')

    def test_create_prereg_team(self):
        """POST /api/prereg/teams/create/ creates a new team."""
        response = self.client.post('/api/prereg/teams/create/', {
            'team_id': 'team_new',
            'team_name': 'Team New',
            'team_color': '#FF6B6B',
        })
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'created')
        self.assertTrue(Team.objects.filter(team_id='team_new').exists())

    def test_create_team_duplicate_id(self):
        """Creating a team with an existing team_id returns 400."""
        response = self.client.post('/api/prereg/teams/create/', {
            'team_id': 'team_alpha',
            'team_name': 'Duplicate',
            'team_color': '#000000',
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['status'], 'error')

    def test_add_prereg_member(self):
        """POST /api/prereg/teams/<id>/add-member/ adds a new member slot."""
        from .models import PreRegisteredMember
        response = self.client.post('/api/prereg/teams/team_alpha/add-member/', {
            'name': 'Charlie',
            'college': 'IIT Delhi',
        })
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['status'], 'created')
        self.assertTrue(
            PreRegisteredMember.objects.filter(team=self.team, name='Charlie').exists()
        )

    def test_add_member_duplicate_name(self):
        """Adding a member with the same name to the same team returns 400."""
        response = self.client.post('/api/prereg/teams/team_alpha/add-member/', {
            'name': 'Alice',
            'college': 'Other College',
        })
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data['status'], 'error')

