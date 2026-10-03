import importlib.machinery
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import time
import unittest

TAP = os.path.join(os.path.dirname(__file__), "..", "bin", "token-tap")
loader = importlib.machinery.SourceFileLoader("token_tap", TAP)
spec = importlib.util.spec_from_loader("token_tap", loader)
tap = importlib.util.module_from_spec(spec)
loader.exec_module(tap)


def msg(mid, **usage):
    return json.dumps({"message": {"role": "assistant", "id": mid, "usage": usage}})


class LineDelta(unittest.TestCase):
    def test_counts_quota_tokens_not_cache_reads(self):
        line = msg("a", input_tokens=2, output_tokens=401, cache_creation_input_tokens=30,
                   cache_read_input_tokens=62627)
        self.assertEqual(tap.line_delta(line, {}), 433)

    def test_streamed_message_only_reports_growth(self):
        seen = {}
        self.assertEqual(tap.line_delta(msg("a", output_tokens=10), seen), 10)
        self.assertEqual(tap.line_delta(msg("a", output_tokens=10), seen), 0)
        self.assertEqual(tap.line_delta(msg("a", output_tokens=25), seen), 15)

    def test_ignores_user_lines_and_garbage(self):
        self.assertEqual(tap.line_delta(json.dumps({"message": {"role": "user"}}), {}), 0)
        self.assertEqual(tap.line_delta("not json", {}), 0)
        self.assertEqual(tap.line_delta("[]", {}), 0)


class EndToEnd(unittest.TestCase):
    def test_new_lines_are_printed_history_is_not(self):
        with tempfile.TemporaryDirectory() as root:
            path = os.path.join(root, "p", "s.jsonl")
            os.makedirs(os.path.dirname(path))
            with open(path, "w") as f:
                f.write(msg("old", output_tokens=999) + "\n")
            env = dict(os.environ, TOKEN_TAP_ROOT=root, TOKEN_TAP_POLL="0.05")
            proc = subprocess.Popen([sys.executable, "-I", TAP], env=env, stdout=subprocess.PIPE, text=True)
            try:
                time.sleep(0.4)
                with open(path, "a") as f:
                    f.write(msg("new", output_tokens=1000) + "\n")
                self.assertEqual(proc.stdout.readline().strip(), "1000")
            finally:
                proc.kill()
                proc.wait()


if __name__ == "__main__":
    unittest.main()
