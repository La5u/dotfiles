#!/usr/bin/env python3
"""Additional agent-window lifecycle tests (stdlib only, mocked launches)."""
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid

loader = importlib.machinery.SourceFileLoader('agent_window', str(Path(__file__).resolve().parents[1] / 'bin/agent-window'))
spec = importlib.util.spec_from_loader(loader.name, loader)
aw = importlib.util.module_from_spec(spec)
loader.exec_module(aw)


class Tests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.state = patch.object(aw, 'STATE', Path(self.tmp.name) / 'state')
        self.state.start()
        self.addCleanup(self.state.stop)
        aw.setup()
        executable = patch.object(aw.shutil, 'which', side_effect=lambda app: app)
        executable.start()
        self.addCleanup(executable.stop)

    def record(self, agent='claude'):
        return dict(window_id=str(uuid.uuid4()), agent=agent, cwd=self.tmp.name,
                    session_id=str(uuid.uuid4()) if agent == 'claude' else None,
                    workspace=None, launched=False)

    def test_state_and_lock(self):
        record = self.record()
        aw.save(record)
        self.assertEqual(aw.load(record['window_id']), record)
        self.assertEqual((aw.STATE / (record['window_id'] + '.json')).stat().st_mode & 0o777, 0o600)
        guard = aw.lock(record['window_id'])
        self.assertIsNone(aw.lock(record['window_id']))
        guard.close()
        with self.assertRaises(ValueError):
            aw.load('../../anything')

    def test_discovery_requires_owned_fd_and_unique_header(self):
        home = Path(self.tmp.name) / 'codex'
        sessions = home / 'sessions'
        sessions.mkdir(parents=True)
        ids = [str(uuid.uuid4()), str(uuid.uuid4())]
        paths = []
        for index, sid in enumerate(ids):
            path = sessions / f'{index}.jsonl'
            path.write_text(json.dumps(dict(type='session_meta', payload=dict(id=sid, cwd=self.tmp.name))) + '\nSECRET TRANSCRIPT\n')
            paths.append(path)
        with patch.dict(os.environ, CODEX_HOME=str(home)), patch.object(aw, 'descendants', return_value={os.getpid()}):
            self.assertIsNone(aw.discover(os.getpid(), self.tmp.name, 0))
            with paths[0].open() as first:
                self.assertEqual(aw.discover(os.getpid(), self.tmp.name, 0), ids[0])
                self.assertIsNone(aw.discover(os.getpid(), '/wrong', 0))
                with paths[1].open() as second:
                    self.assertIsNone(aw.discover(os.getpid(), self.tmp.name, 0))

    def test_exit_and_resume(self):
        for code in (0, 1, -15):
            record = self.record()
            aw.save(record)
            with patch.object(aw, 'move_workspace'), patch.object(aw.subprocess, 'Popen') as popen:
                popen.return_value.poll.return_value = code
                popen.return_value.wait.return_value = code
                aw.run(record['window_id'])
                self.assertEqual(popen.call_args.args[0], ['claude', '--session-id', record['session_id']])
            self.assertEqual((aw.STATE / (record['window_id'] + '.json')).exists(), code != 0)
        record['launched'] = True
        aw.save(record)
        with patch.object(aw, 'move_workspace'), patch.object(aw.subprocess, 'Popen') as popen:
            popen.return_value.poll.return_value = 1
            popen.return_value.wait.return_value = 1
            aw.run(record['window_id'])
            self.assertEqual(popen.call_args.args[0], ['claude', '--resume', record['session_id']])

    def test_codex_unknown_refuses_guess(self):
        record = self.record('codex')
        record['launched'] = True
        aw.save(record)
        with patch.object(aw, 'move_workspace'), patch.object(aw.subprocess, 'Popen') as popen:
            self.assertEqual(aw.run(record['window_id']), 1)
            popen.assert_not_called()

    def test_spawn_argv(self):
        record = self.record()
        with patch.object(aw.subprocess, 'Popen') as popen:
            aw.spawn(record)
            self.assertEqual(popen.call_args.args[0], ['ghostty', '-e', aw.SELF, '_run', record['window_id']])


if __name__ == '__main__':
    unittest.main()
