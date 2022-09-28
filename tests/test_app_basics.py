import unittest

from app import hello


class AppBasicsTestCase(unittest.TestCase):
    def test_app_hello(self):
        result = hello()
        self.assertTrue('Hello' in result)
