#!/usr/bin/env python3
"""Black-box tests for the installed pomelodb instance manager."""

import os
import pathlib
import shutil
import stat
import subprocess
import tempfile
import unittest


SOURCE_ROOT = pathlib.Path(__file__).resolve().parents[3]
POMELODB_SOURCE = SOURCE_ROOT / "gpMgmt" / "bin" / "pomelodb"


class PomeloDbCommandTest(unittest.TestCase):
    def setUp(self):
        self.workdir = pathlib.Path(tempfile.mkdtemp(prefix="pomelodb-test-"))
        self.prefix = self.workdir / "pomelodb"
        self.bindir = self.prefix / "bin"
        self.bindir.mkdir(parents=True)
        self.command_log = self.workdir / "commands.log"

    def tearDown(self):
        shutil.rmtree(self.workdir)

    def test_commands_use_only_the_installed_configuration(self):
        """A wrong configured directory or missing log argument must fail this test."""
        self.assertTrue(POMELODB_SOURCE.is_file(), "pomelodb command is missing")

        command = self.bindir / "pomelodb"
        shutil.copy2(POMELODB_SOURCE, command)
        command.chmod(command.stat().st_mode | stat.S_IXUSR)
        data_dir = self.workdir / "database-data"
        log_dir = self.workdir / "database-logs"
        (self.prefix / "pomelodb.conf").write_text(
            "data_directory=%s\nlog_directory=%s\n"
            "initdb_options=--encoding UTF8\nserver_options=-p 6432\n"
            "stop_mode=fast\n" % (data_dir, log_dir), encoding="utf-8")
        self._write_fake_binary(
            "initdb", "printf '%s\\n' \"$*\" >> \"$POMELODB_TEST_LOG\"; "
            "mkdir -p \"$2\"; : > \"$2/postgresql.conf\"")
        self._write_fake_binary("pg_ctl", "printf '%s\\n' \"$*\" >> \"$POMELODB_TEST_LOG\"")

        environment = os.environ.copy()
        environment["POMELODB_TEST_LOG"] = str(self.command_log)
        for action in ("init", "start", "stop", "reload", "status"):
            completed = subprocess.run([str(command), action], env=environment,
                                       text=True, capture_output=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)

        self.assertEqual(self.command_log.read_text(encoding="utf-8").splitlines(), [
            "-D %s --encoding UTF8" % data_dir,
            "start -D %s -l %s -o -p 6432 -w" %
            (data_dir, log_dir / "pomelodb-startup.log"),
            "stop -D %s -m fast -w" % data_dir,
            "reload -D %s" % data_dir,
            "status -D %s" % data_dir,
        ])
        postgresql_conf = (data_dir / "postgresql.conf").read_text(encoding="utf-8")
        self.assertIn("logging_collector = on", postgresql_conf)
        self.assertIn("log_directory = '%s'" % log_dir, postgresql_conf)

    def test_rejects_shared_or_nested_data_and_log_directories(self):
        command = self.bindir / "pomelodb"
        shutil.copy2(POMELODB_SOURCE, command)
        command.chmod(command.stat().st_mode | stat.S_IXUSR)
        data_dir = self.workdir / "database-data"
        (self.prefix / "pomelodb.conf").write_text(
            "data_directory=%s\nlog_directory=%s/logs\n" %
            (data_dir, data_dir), encoding="utf-8")

        completed = subprocess.run([str(command), "status"], text=True,
                                   capture_output=True)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("must be separate", completed.stderr)

    def _write_fake_binary(self, name, body):
        binary = self.bindir / name
        binary.write_text("#!/usr/bin/env bash\nset -eu\n%s\n" % body,
                          encoding="utf-8")
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
