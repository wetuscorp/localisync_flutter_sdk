"""Process restart evidence must never terminate a reused foreign PID."""
import subprocess
import unittest
from unittest.mock import patch

import physical_restart as subject


class ProcessBoundaryTests(unittest.TestCase):
    def test_natural_exit_is_a_valid_boundary_without_a_kill(self):
        with patch.object(subject, 'device_query', return_value={'runningProcesses': []}), \
                patch.object(subject.subprocess, 'run') as run:
            self.assertEqual(subject.stop_test_process('device', 42, 'file:///test/'), 'already-exited')
            run.assert_not_called()

    def test_reused_foreign_pid_is_never_terminated(self):
        state = {'runningProcesses': [{'processIdentifier': 42, 'executable': 'file:///other/Runner'}]}
        with patch.object(subject, 'device_query', return_value=state), \
                patch.object(subject.subprocess, 'run') as run:
            with self.assertRaisesRegex(RuntimeError, 'another application'):
                subject.stop_test_process('device', 42, 'file:///test/')
            run.assert_not_called()

    def test_natural_exit_racing_termination_is_verified(self):
        states = [{'runningProcesses': [{'processIdentifier': 42, 'executable': 'file:///test/Runner'}]},
                  {'runningProcesses': []}]
        with patch.object(subject, 'device_query', side_effect=states), \
                patch.object(subject.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            self.assertEqual(subject.stop_test_process('device', 42, 'file:///test/'), 'exited-during-stop')

    def test_failed_termination_does_not_claim_a_restart(self):
        state = {'runningProcesses': [{'processIdentifier': 42, 'executable': 'file:///test/Runner'}]}
        with patch.object(subject, 'device_query', return_value=state), \
                patch.object(subject.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaisesRegex(RuntimeError, 'did not terminate'):
                subject.stop_test_process('device', 42, 'file:///test/')


if __name__ == '__main__':
    unittest.main()
