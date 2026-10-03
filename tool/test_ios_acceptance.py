import unittest
from ios_acceptance import completed_tests


class CompletionEvidenceTest(unittest.TestCase):
    def test_empty_or_skipped_suite_is_not_acceptance(self):
        self.assertEqual(completed_tests('All tests passed.\n'), 0)

    def test_command_echo_is_not_acceptance(self):
        self.assertEqual(completed_tests('Running echo LOCALISYNC_IOS_ACCEPTANCE={"passed":1}'), 0)

    def test_exact_callback_marker(self):
        self.assertEqual(completed_tests('All tests passed.\nLOCALISYNC_IOS_ACCEPTANCE={"passed":1}\n'), 1)

    def test_duplicate_callbacks_are_not_single_acceptance(self):
        self.assertEqual(completed_tests('LOCALISYNC_IOS_ACCEPTANCE={"passed":1}\n' * 2), 2)
