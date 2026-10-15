import gzip
import hashlib
import json
from pathlib import Path
import subprocess
from uuid import UUID

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-large-list-traversal'
test_source = 'PlannerFixtureUITests/LargeListTraversalJourneyTests.swift'
qualified_sources = json.loads((packet / 'phone-row-snapshots/source-sha256.json').read_text())
assert len(qualified_sources) == 213
for phase_name in ['phone-initial', 'phone-row-snapshots', 'tablet-row-snapshots', 'mac-build']:
    phase = packet / phase_name
    sources = json.loads((phase / 'source-sha256.json').read_text())
    assert sources.keys() == qualified_sources.keys()
    for source, expected_hash in sources.items():
        if phase_name == 'phone-initial' and source == test_source:
            continue
        assert hashlib.sha256((root / source).read_bytes()).hexdigest() == expected_hash, (phase_name, source)
    if phase_name != 'mac-build':
        test_snapshot = gzip.decompress((phase / 'LargeListTraversalJourneyTests.swift.gz').read_bytes())
        assert hashlib.sha256(test_snapshot).hexdigest() == sources[test_source]
    exit_status = json.loads((phase / 'exit.json').read_text())
    if phase_name == 'phone-initial':
        assert exit_status['exitCode'] == 75
        initial_log = gzip.decompress((phase / 'test.log.gz').read_bytes()).decode()
        assert '** TEST INTERRUPTED **' in initial_log
        assert ': error: -[PlannerFixtureUITests.LargeListTraversalJourneyTests' not in initial_log
        continue
    assert exit_status['exitCode'] == 0
    if phase_name == 'mac-build':
        assert exit_status['runtimeTests'] == 0
        continue
    summary = json.loads((phase / 'result-summary.json').read_text())
    assert summary['totalTestCount'] == summary['passedTests'] == 1
    assert summary['failedTests'] == summary['skippedTests'] == 0
    actual_log = gzip.decompress((phase / 'test.log.gz').read_bytes()).decode()
    assert "Test Case '-[PlannerFixtureUITests.LargeListTraversalJourneyTests testEveryListCanBeTraversedInBothDirectionsWithoutChangingItsIdentity]' passed (" in actual_log
    images = list((phase / 'attachments').glob('*.png'))
    assert len(images) == 5
    manifest = json.loads((phase / 'identity-attachments/manifest.json').read_text())
    identity_attachments = [attachment for test in manifest for attachment in test['attachments'] if attachment['suggestedHumanReadableName'].startswith('Two hundred List identities observed in both traversal directions')]
    assert len(identity_attachments) == 1
    identity_file = phase / 'identity-attachments' / identity_attachments[0]['exportedFileName']
    lines = identity_file.read_text().splitlines()
    assert len(lines) == 200
    identities = dict(line.split(': ', 1) for line in lines)
    assert sorted(identities) == [f'Scale List {index:03d}' for index in range(1, 201)]
    assert len(set(identities.values())) == 200
    for identity in identities.values():
        assert identity.startswith('saved.list.')
        UUID(identity.removeprefix('saved.list.'))
phone_products = json.loads((packet / 'phone-row-snapshots/product-sha256.json').read_text())
tablet_before = json.loads((packet / 'tablet-row-snapshots/product-before-sha256.json').read_text())
tablet_after = json.loads((packet / 'tablet-row-snapshots/product-sha256.json').read_text())
assert phone_products == tablet_before == tablet_after
subprocess.run(['git', 'diff', '--exit-code', '5b3d401', '--', 'Planner', 'PlannerFixtures', 'Packages', 'Configuration', 'Planner.xcodeproj'], cwd=root, check=True)
print('Verified 213 frozen source/configuration hashes per epoch, two complete simulator journeys, each 200-identity attachment, unchanged tablet products, zero Mac runtime credit and unchanged production sources.')
