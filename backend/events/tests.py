from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework.authtoken.models import Token
from .models import Participant


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
