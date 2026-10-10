import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).resolve().parents[1] / 'bin/agent-window'
loader = importlib.machinery.SourceFileLoader('agent_window', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
a = importlib.util.module_from_spec(spec)
loader.exec_module(a)

class Tests(unittest.TestCase):
    def test_passthrough_exact_args_no_records(self):
        with tempfile.TemporaryDirectory() as d:
            exe = Path(d) / 'claude'
            exe.write_text('#!/usr/bin/env python3\nimport sys,json\nprint(json.dumps(sys.argv[1:]))\n')
            exe.chmod(0o700)
            argv = ['--resume', 'not-a-uuid', '--print', 'two words', '--continue']
            env = dict(os.environ, PATH=d+':'+os.environ['PATH'], XDG_STATE_HOME=d+'/state')
            result = subprocess.run([str(SCRIPT), 'here', 'claude', *argv], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(result.stdout), argv)
            self.assertFalse((Path(d)/'state').exists())

    def test_here_records_current_cwd(self):
        with tempfile.TemporaryDirectory() as d, patch.object(a, 'STATE', Path(d)), patch.object(a, 'workspace', return_value=5), patch.object(a, 'run', return_value=0) as run, patch('sys.argv', ['agent-window', 'here', 'claude']), patch.object(a.shutil, 'which', return_value='/bin/true'):
            self.assertEqual(a.main(), 0)
            record = a.load(run.call_args.args[0])
            self.assertEqual(record['cwd'], os.getcwd())
            self.assertFalse(record['launched'])
            self.assertIsNotNone(record['session_id'])

    def test_fd_discovery_large_header_and_ownership(self):
        with tempfile.TemporaryDirectory() as d, patch.dict(os.environ, CODEX_HOME=d):
            sessions = Path(d)/'sessions'
            sessions.mkdir()
            path = sessions/'rollout.jsonl'
            sid = '00000000-0000-4000-8000-000000000001'
            started = time.time_ns()
            path.write_text(json.dumps({'type':'session_meta','payload':{'id':sid,'cwd':os.getcwd(),'instructions':'x'*20000}})+'\n')
            with path.open() as f:
                self.assertEqual(a.discover(os.getpid(), os.getcwd(), started), sid)
                self.assertIsNone(a.discover(os.getpid(), '/wrong', started))
            self.assertIsNone(a.discover(os.getpid(), os.getcwd(), started))

    def test_workspace_safe_lua(self):
        def hypr(*args):
            if args == ('-j', 'clients'):
                return json.dumps([{'pid':os.getpid(),'address':'0xab12'}])
            return ''
        with patch.object(a, 'hypr', side_effect=hypr) as call:
            a.move_workspace(5)
            self.assertEqual(call.call_args.args, ('dispatch', 'hl.dsp.window.move({ workspace = 5, window = "address:0xab12", follow = false })'))
            call.reset_mock()
            a.move_workspace('5;evil()')
            call.assert_not_called()

if __name__ == '__main__':
    unittest.main()
