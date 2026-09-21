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
        coordinator = self.workdir / "mpp" / "coordinator"
        segment = self.workdir / "mpp" / "segment"
        log_dir = self.workdir / "database-logs"
        (self.prefix / "pomelodb.conf").write_text(
            "cluster_mode=mpp\ncoordinator_data_directory=%s\n"
            "segment_data_directories=%s\nlog_directory=%s\nstop_mode=fast\n"
            % (coordinator, segment, log_dir), encoding="utf-8")
        coordinator.mkdir(parents=True)
        segment.mkdir(parents=True)
        for data_dir in (coordinator, segment):
            (data_dir / "postgresql.conf").write_text("# test\n", encoding="utf-8")
        self._write_fake_binary("pg_ctl", "printf '%s\\n' \"$*\" >> \"$POMELODB_TEST_LOG\"")
        self._write_fake_binary("postgres", "cat >/dev/null")

        environment = os.environ.copy()
        environment["POMELODB_TEST_LOG"] = str(self.command_log)
        for action in ("init", "start", "stop", "reload", "status"):
            completed = subprocess.run([str(command), action], env=environment,
                                       text=True, capture_output=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)

        self.assertEqual(self.command_log.read_text(encoding="utf-8").splitlines(), [
            "start -D %s -l %s -o -c gp_role=execute -w" %
            (segment, log_dir / "segment-startup.log"),
            "start -D %s -l %s -o -c gp_role=dispatch -w" %
            (coordinator, log_dir / "coordinator-startup.log"),
            "stop -D %s -m fast -w" % coordinator,
            "stop -D %s -m fast -w" % segment,
            "reload -D %s" % coordinator,
            "reload -D %s" % segment,
            "status -D %s" % coordinator,
            "status -D %s" % segment,
        ])
        postgresql_conf = (coordinator / "postgresql.conf").read_text(encoding="utf-8")
        self.assertIn("logging_collector = on", postgresql_conf)
        self.assertIn("log_directory = '%s'" % log_dir, postgresql_conf)

    def test_rejects_shared_or_nested_data_and_log_directories(self):
        command = self.bindir / "pomelodb"
        shutil.copy2(POMELODB_SOURCE, command)
        command.chmod(command.stat().st_mode | stat.S_IXUSR)
        coordinator = self.workdir / "mpp" / "coordinator"
        segment = self.workdir / "mpp" / "segment"
        coordinator.mkdir(parents=True)
        segment.mkdir(parents=True)
        for data_dir in (coordinator, segment):
            (data_dir / "postgresql.conf").write_text("# test\n", encoding="utf-8")
        (self.prefix / "pomelodb.conf").write_text(
            "cluster_mode=mpp\ncoordinator_data_directory=%s\n"
            "segment_data_directories=%s\nlog_directory=%s/logs\n" %
            (coordinator, segment, coordinator), encoding="utf-8")

        completed = subprocess.run([str(command), "status"], text=True,
                                   capture_output=True)
        self.assertEqual(completed.returncode, 2)
        self.assertIn("must be separate", completed.stderr)

    def test_mpp_mode_manages_coordinator_and_segments_without_utility_flags(self):
        command = self.bindir / "pomelodb"
        shutil.copy2(POMELODB_SOURCE, command)
        command.chmod(command.stat().st_mode | stat.S_IXUSR)
        coordinator = self.prefix / "mpp" / "coordinator" / "pomelodb-1"
        segment = self.prefix / "mpp" / "segment" / "pomelodb0"
        coordinator.mkdir(parents=True)
        segment.mkdir(parents=True)
        for data_dir in (coordinator, segment):
            (data_dir / "postgresql.conf").write_text("# test\n", encoding="utf-8")
        log_dir = self.prefix / "logs"
        (self.prefix / "pomelodb.conf").write_text(
            "cluster_mode=mpp\ncoordinator_data_directory=%s\n"
            "segment_data_directories=%s\nlog_directory=%s\nstop_mode=fast\n"
            % (coordinator, segment, log_dir), encoding="utf-8")
        self._write_fake_binary("pg_ctl", "printf '%s\\n' \"$*\" >> \"$POMELODB_TEST_LOG\"")
        self._write_fake_binary("postgres", "cat >/dev/null")

        environment = os.environ.copy()
        environment["POMELODB_TEST_LOG"] = str(self.command_log)
        for action in ("init", "start", "stop", "reload", "status"):
            completed = subprocess.run([str(command), action], env=environment,
                                       text=True, capture_output=True)
            self.assertEqual(completed.returncode, 0, completed.stderr)

        commands = self.command_log.read_text(encoding="utf-8").splitlines()
        self.assertIn("start -D %s -l %s -o -c gp_role=execute -w" %
                      (segment, log_dir / "segment-startup.log"), commands)
        self.assertIn("start -D %s -l %s -o -c gp_role=dispatch -w" %
                      (coordinator, log_dir / "coordinator-startup.log"), commands)
        self.assertNotIn("gp_role=utility", "\n".join(commands))

    def _write_fake_binary(self, name, body):
        binary = self.bindir / name
        binary.write_text("#!/usr/bin/env bash\nset -eu\n%s\n" % body,
                          encoding="utf-8")
        binary.chmod(binary.stat().st_mode | stat.S_IXUSR)


if __name__ == "__main__":
    unittest.main()
