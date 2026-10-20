#!/usr/bin/env python3
"""Verify an actual XCTest log and remove its disposable stores after host exit."""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import uuid
from pathlib import Path


def read_fixtures(log):
    records = {}
    for line in log.splitlines():
        marker = "PLANNER_INTENT_FIXTURE "
        if marker not in line:
            continue
        record, _ = json.JSONDecoder().raw_decode(line.split(marker, 1)[1])
        if not isinstance(record, dict):
            raise TypeError("A fixture record must be an object.")
        if set(record) != {"formatVersion", "directory", "hostProcessIdentifier"}:
            raise ValueError("Unexpected fixture record fields.")
        if type(record["formatVersion"]) is not int or record["formatVersion"] != 1:
            raise ValueError("Unsupported fixture record version.")
        identifier = record["hostProcessIdentifier"]
        if type(identifier) is not int or not 1 < identifier <= 2**31 - 1:
            raise ValueError("Invalid test-host process identifier.")
        if not isinstance(record["directory"], str):
            raise TypeError("A fixture directory must be a path string.")
        directory = Path(record["directory"])
        if (
            not directory.is_absolute()
            or directory.parent.name != "PlannerIntentFixtures"
        ):
            raise ValueError("The record is outside the disposable fixture directory.")
        uuid.UUID(directory.name)
        if directory.is_symlink() or directory != directory.resolve(strict=True):
            raise ValueError("A fixture must be a canonical directory, not a symlink.")
        ownership = directory / ".planner-intent-fixture.json"
        if ownership.is_symlink() or json.loads(ownership.read_text()) != record:
            raise ValueError(
                "The fixture ownership marker does not match its log record."
            )
        if directory in records and records[directory] != record:
            raise ValueError("Conflicting fixture records.")
        records[directory] = record
    if not records:
        raise ValueError("The log contains no owned Intent fixtures.")
    return records


def require_closed_hosts(records):
    identifiers = sorted(
        {record["hostProcessIdentifier"] for record in records.values()}
    )
    for identifier in identifiers:
        try:
            os.kill(identifier, 0)
        except ProcessLookupError:
            continue
        raise ValueError(
            "A recorded test host is still alive; its fixtures are preserved."
        )
    return identifiers


def require_closed_databases(records):
    databases = sorted(
        str(path)
        for directory in records
        for path in directory.rglob("*.sqlite*")
        if path.is_file()
    )
    for offset in range(0, len(databases), 64):
        result = subprocess.run(
            ["/usr/sbin/lsof", "-t", "--", *databases[offset : offset + 64]],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 1 or result.stdout.strip() or result.stderr.strip():
            raise ValueError(
                "Database handles remain open or cannot be verified; fixtures are preserved."
            )


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path)
    parser.add_argument("--report", required=True, type=Path)
    arguments = parser.parse_args()
    report = {
        "success": False,
        "removedDirectories": [],
        "verifierSha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    }
    report_permitted = False
    try:
        report_path = arguments.report.resolve()
        log_path = arguments.log.resolve()
        same_log = report_path == log_path
        if arguments.report.exists() and arguments.log.exists():
            same_log = same_log or arguments.report.samefile(arguments.log)
        if same_log or "PlannerIntentFixtures" in report_path.parts:
            raise ValueError(
                "The report must preserve the original log and stay outside fixture storage."
            )
        report_permitted = True
        content = arguments.log.read_bytes()
        report["sourceLogSha256"] = hashlib.sha256(content).hexdigest()
        log = content.decode(errors="replace")
        markers = [
            "vnode unlinked while in use",
            "invalidated open fd",
            "database integrity compromised",
        ]
        report["diagnosticCounts"] = {marker: log.count(marker) for marker in markers}
        if any(report["diagnosticCounts"].values()):
            raise ValueError(
                "The original test log contains SQLite lifetime diagnostics."
            )
        completed_suite = re.search(
            r"^Test Suite '(?:All tests|Selected tests)' passed at", log, re.MULTILINE
        )
        failed_suite = re.search(r"^Test Suite '.+' failed at", log, re.MULTILINE)
        if not completed_suite or failed_suite or "** TEST FAILED **" in log:
            raise ValueError("A successful completed XCTest invocation is required.")
        if not re.search(r"Executed [1-9][0-9]* tests?, with 0 failures", log):
            raise ValueError("The log does not establish passing test execution.")
        records = read_fixtures(log)
        report["fixtureCount"] = len(records)
        for directory in records:
            if arguments.report.resolve().is_relative_to(directory):
                raise ValueError("The report must be outside the disposable fixtures.")
        arguments.report.parent.mkdir(parents=True, exist_ok=True)
        arguments.report.write_text(json.dumps(report, indent=2) + "\n")
        report["hostProcessIdentifiers"] = require_closed_hosts(records)
        require_closed_databases(records)
        for directory in records:
            report["activeDirectory"] = str(directory)
            arguments.report.write_text(json.dumps(report, indent=2) + "\n")
            shutil.rmtree(directory)
            report["removedDirectories"].append(str(directory))
            report.pop("activeDirectory")
            arguments.report.write_text(json.dumps(report, indent=2) + "\n")
        report["success"] = True
    except (OSError, TypeError, ValueError) as error:
        report["error"] = str(error)
    if report_permitted:
        try:
            arguments.report.parent.mkdir(parents=True, exist_ok=True)
            arguments.report.write_text(json.dumps(report, indent=2) + "\n")
        except OSError as error:
            report["success"] = False
            report["error"] = f"Could not persist the lifecycle report: {error}"
    print(
        json.dumps(
            {
                "success": report["success"],
                "removedFixtures": len(report["removedDirectories"]),
                "error": report.get("error"),
            }
        )
    )
    return 0 if report["success"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
