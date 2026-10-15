import gzip
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-catalog-sorting'
test_source = 'PlannerFixtureUITests/ContainerCatalogSortJourneyTests.swift'
final_phase = packet / 'mac-native-switch-qualified'
final_sources = json.loads((final_phase / 'source-sha256.json').read_text())
assert len(final_sources) == 214
assert any(source.endswith('.resolved') for source in final_sources)
phases = [
    ('mac-idle-retry', 2, 1, 1, 5),
    ('mac-estimate-role-observation', 1, 0, 1, 2),
    ('mac-native-switch-qualified', 2, 2, 0, 8),
]
for phase_name, total_count, passed_count, failed_count, capture_count in phases:
    phase = packet / phase_name
    sources = json.loads((phase / 'source-sha256.json').read_text())
    assert sources.keys() == final_sources.keys()
    for source, expected_hash in sources.items():
        if source != test_source or phase_name == 'mac-native-switch-qualified':
            assert hashlib.sha256((root / source).read_bytes()).hexdigest() == expected_hash, (phase_name, source)
        snapshot = phase / (Path(source).name + '.gz')
        if snapshot.is_file():
            assert hashlib.sha256(gzip.decompress(snapshot.read_bytes())).hexdigest() == expected_hash
    summary = json.loads((phase / 'result-summary.json').read_text())
    assert summary['totalTestCount'] == total_count
    assert summary['passedTests'] == passed_count
    assert summary['failedTests'] == failed_count
    assert summary['skippedTests'] == 0
    exit_status = json.loads((phase / 'exit.json').read_text())
    assert exit_status['exitCode'] == (0 if failed_count == 0 else 65)
    manifest = json.loads((phase / 'fixture-window-capture-manifest.json').read_text())
    assert len(manifest) == capture_count
    shared_images = set((phase / 'fixture-window-images').glob('*.png'))
    assert shared_images == {phase / 'fixture-window-images' / entry['sharedFile'] for entry in manifest}
    for entry in manifest:
        shared = phase / 'fixture-window-images' / entry['sharedFile']
        assert shared.read_bytes() == Path(entry['originalExportPath']).read_bytes()
        assert hashlib.sha256(shared.read_bytes()).hexdigest() == entry['sha256']
    original_scope = json.loads((phase / 'image-export-scope.json').read_text())
    original_manifest = Path(original_scope['originalManifestLocalPath'])
    assert hashlib.sha256(original_manifest.read_bytes()).hexdigest() == original_scope['originalManifestSHA256']

products = json.loads((final_phase / 'product-sha256.json').read_text())
assert len(products) == 3
for product, expected_hash in products.items():
    assert hashlib.sha256(Path(product).read_bytes()).hexdigest() == expected_hash
log = gzip.decompress((final_phase / 'test.log.gz').read_bytes()).decode()
assert "testCatalogsRememberSeparateNativeSortsAcrossRelaunchAndDatasetChanges]' passed (119.001 seconds)" in log
assert "testSharedEstimateEditsRefreshBothCatalogsWithoutReplacingValidSelection]' passed (98.358 seconds)" in log
assert '** TEST SUCCEEDED **' in log
assert len(json.loads((final_phase / 'result-summary.json').read_text())['runtimeWarnings']) == 1
observation = packet / 'mac-estimate-role-observation/fixture-window-observation.txt'
assert any('Switch' in line and "saved.item.edit.estimate.enabled" in line and 'value: 1' in line for line in observation.read_text().splitlines())
origin = json.loads((packet / 'mac-estimate-role-observation/observation-origin.json').read_text())
assert hashlib.sha256(observation.read_bytes()).hexdigest() == origin['sha256']

compatibility = json.loads((packet / 'mobile-compatibility.json').read_text())
qualified_mobile = gzip.decompress((root / compatibility['qualifiedSourceSnapshot']).read_bytes())
final_source = (root / test_source).read_bytes()
assert hashlib.sha256(qualified_mobile).hexdigest() == compatibility['qualifiedSourceSHA256']
assert hashlib.sha256(final_source).hexdigest() == compatibility['finalSourceSHA256']
assert qualified_mobile.replace(b'let estimateToggle = estimate.checkBoxes.firstMatch', b'let estimateToggle = estimate', 1) == final_source
phone_summary = json.loads((root / compatibility['reusedPhoneResults']).read_text())
assert phone_summary['passedTests'] == phone_summary['totalTestCount'] == 2
assert phone_summary['failedTests'] == phone_summary['skippedTests'] == 0
assert compatibility['newMobileRuntimeTests'] == 0

inspection = json.loads((packet / 'visual-inspection.json').read_text())['files']
assert len(inspection) == 15
for entry in inspection:
    assert hashlib.sha256((packet / entry['file']).read_bytes()).hexdigest() == entry['sha256']
subprocess.run(['git', 'diff', '--exit-code', 'bad1718', '--', 'Planner', 'PlannerFixtures', 'Packages', 'Configuration', 'Planner.xcodeproj'], cwd=root, check=True)
print('Verified three 214-file source epochs, two complete Mac passes, unchanged production, exact mobile compatibility, three final products and 15 inspected original fixture-window captures. The internal runtime warning remains recorded.')
