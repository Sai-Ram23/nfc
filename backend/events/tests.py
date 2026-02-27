from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from .models import Team, Participant


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
        self.assertEqual(response.data['status'], 'invalid')

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
        response = self.client.get('/api/teams/stats/')
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['total_teams'], 1)
        self.assertEqual(response.data['solo_participants'], 1)
        self.assertEqual(response.data['average_team_size'], 3.0)
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
