"""Exercise fixture cleanup through its real CLI, process and filesystem boundaries."""

import json
import os
import sqlite3
import subprocess
import tempfile
import unittest
import uuid
from pathlib import Path


class StoreFixtureCleanupTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="PlannerFixtureVerifier-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.verifier = (
            Path(__file__).resolve().parents[1] / "verify-intent-fixtures.py"
        )
        process = subprocess.Popen(["/usr/bin/true"])
        process.wait()
        self.closed_process_identifier = process.pid

    def fixture(self, namespace="PlannerStoreFixtures", process_identifier=None):
        directory = self.root / namespace / str(uuid.uuid4())
        directory.mkdir(parents=True)
        record = {
            "formatVersion": 1,
            "directory": str(directory),
            "hostProcessIdentifier": process_identifier
            or self.closed_process_identifier,
        }
        marker = ".planner-store-fixture.json"
        if namespace == "PlannerIntentFixtures":
            marker = ".planner-intent-fixture.json"
        (directory / marker).write_text(json.dumps(record))
        (directory / "sentinel").write_text("Preserve unless verified closed.")
        return directory, record

    def verify(self, records, completion=None, report_path=None):
        lines = []
        for prefix, record in records:
            lines.append(prefix + " " + json.dumps(record))
        if completion is None:
            completion = (
                "Test Suite 'Selected tests' passed at 2026-10-22.\n"
                "Executed 0 tests, with 0 failures\n"
                "✔ Test run with 1 test in 1 suite passed after 0.1 seconds.\n"
                "** TEST SUCCEEDED **\n"
            )
        log = self.root / "test.log"
        log.write_text("\n".join(lines) + "\n" + completion)
        report_path = report_path or self.root / "report.json"
        execution = subprocess.run(
            ["python3", str(self.verifier), str(log), "--report", str(report_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        return execution, json.loads(execution.stdout)

    def test_swift_testing_store_fixture_is_removed_after_process_exit(self):
        directory, record = self.fixture()
        execution, report = self.verify([("PLANNER_STORE_FIXTURE", record)])
        self.assertEqual(execution.returncode, 0, execution.stdout)
        self.assertTrue(report["success"])
        self.assertEqual(report["removedFixtures"], 1)
        self.assertFalse(directory.exists())

    def test_mixed_intent_and_store_fixtures_keep_individual_ownership(self):
        store, store_record = self.fixture()
        intent, intent_record = self.fixture("PlannerIntentFixtures")
        execution, report = self.verify(
            [
                ("PLANNER_STORE_FIXTURE", store_record),
                ("PLANNER_INTENT_FIXTURE", intent_record),
            ]
        )
        self.assertEqual(execution.returncode, 0, execution.stdout)
        self.assertEqual(report["removedFixtures"], 2)
        self.assertFalse(store.exists())
        self.assertFalse(intent.exists())

    def test_live_store_host_preserves_its_fixture(self):
        directory, record = self.fixture(process_identifier=os.getpid())
        execution, report = self.verify([("PLANNER_STORE_FIXTURE", record)])
        self.assertEqual(execution.returncode, 1)
        self.assertIn("still alive", report["error"])
        self.assertTrue((directory / "sentinel").exists())

    def test_open_database_in_another_process_preserves_the_fixture(self):
        directory, record = self.fixture()
        database = directory / "Planner.sqlite"
        connection = sqlite3.connect(database)
        try:
            connection.execute("CREATE TABLE retained(value TEXT)")
            connection.commit()
            execution, report = self.verify([("PLANNER_STORE_FIXTURE", record)])
        finally:
            connection.close()
        self.assertEqual(execution.returncode, 1)
        self.assertIn("Database handles remain open", report["error"])
        self.assertTrue((directory / "sentinel").exists())

    def test_store_record_cannot_authorize_an_intent_namespace(self):
        directory, record = self.fixture("PlannerIntentFixtures")
        execution, report = self.verify([("PLANNER_STORE_FIXTURE", record)])
        self.assertEqual(execution.returncode, 1)
        self.assertIn("outside the disposable", report["error"])
        self.assertTrue((directory / "sentinel").exists())

    def test_report_cannot_be_written_inside_store_fixture_storage(self):
        directory, record = self.fixture()
        report_path = self.root / "PlannerStoreFixtures" / "report.json"
        execution, report = self.verify(
            [("PLANNER_STORE_FIXTURE", record)], report_path=report_path
        )
        self.assertEqual(execution.returncode, 1)
        self.assertIn("outside fixture storage", report["error"])
        self.assertFalse(report_path.exists())
        self.assertTrue((directory / "sentinel").exists())

    def test_zero_tests_do_not_authorize_cleanup(self):
        directory, record = self.fixture()
        execution, report = self.verify(
            [("PLANNER_STORE_FIXTURE", record)],
            completion="Test Suite 'Selected tests' passed at 2026-10-22.\nExecuted 0 tests, with 0 failures\n",
        )
        self.assertEqual(execution.returncode, 1)
        self.assertFalse(report["success"])
        self.assertTrue((directory / "sentinel").exists())

    def test_failed_swift_testing_run_preserves_fixture_after_a_passing_xctest_suite(
        self,
    ):
        directory, record = self.fixture()
        execution, report = self.verify(
            [("PLANNER_STORE_FIXTURE", record)],
            completion=(
                "Test Suite 'Selected tests' passed at 2026-10-22.\n"
                "Executed 1 test, with 0 failures\n"
                "✘ Test run with 1 test in 1 suite failed after 0.1 seconds.\n"
                "** TEST FAILED **\n"
            ),
        )
        self.assertEqual(execution.returncode, 1)
        self.assertFalse(report["success"])
        self.assertTrue((directory / "sentinel").exists())


if __name__ == "__main__":
    unittest.main()
