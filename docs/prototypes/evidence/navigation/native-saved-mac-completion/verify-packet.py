import gzip
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-completion'
test_source = 'PlannerNavigationUITests/SavedAppearanceJourneyTests.swift'
final_name = 'tablet-toolbar-scoped-qualified'
final_sources = json.loads((packet / final_name / 'source-sha256.json').read_text())
assert len(final_sources) == 214
phases = [
    ('mac-initial', 2, 0, 2, 0),
    ('mac-native-create-overflow', 2, 2, 0, 3),
    ('mac-both-global-qualified', 2, 0, 2, 0),
    ('phone-both-global-qualified', 1, 1, 0, 3),
    ('tablet-both-global-qualified', 1, 0, 1, 0),
    ('mac-serialized-qualified', 2, 2, 0, 4),
    ('phone-adaptive-qualified', 2, 2, 0, 4),
    ('tablet-adaptive-qualified', 2, 0, 2, 0),
    ('tablet-toolbar-qualified', 2, 1, 1, 2),
    (final_name, 2, 2, 0, 4),
]
for phase_name, total_count, passed_count, failed_count, capture_count in phases:
    phase = packet / phase_name
    sources = json.loads((phase / 'source-sha256.json').read_text())
    assert sources.keys() == final_sources.keys()
    for source, expected_hash in sources.items():
        historical_controller = phase_name != final_name and source == test_source
        if not historical_controller:
            assert hashlib.sha256((root / source).read_bytes()).hexdigest() == expected_hash, (phase_name, source)
        snapshot = phase / (Path(source).name + '.gz')
        if snapshot.is_file():
            assert hashlib.sha256(gzip.decompress(snapshot.read_bytes())).hexdigest() == expected_hash
    summary = json.loads((phase / 'result-summary.json').read_text())
    assert summary['totalTestCount'] == total_count
    assert summary['passedTests'] == passed_count
    assert summary['failedTests'] == failed_count
    assert summary['skippedTests'] == 0
    assert json.loads((phase / 'exit.json').read_text())['exitCode'] == (0 if failed_count == 0 else 65)
    captures = json.loads((phase / 'fixture-window-capture-manifest.json').read_text())
    assert len(captures) == capture_count
    assert set((phase / 'fixture-window-images').glob('*.png')) == {
        phase / 'fixture-window-images' / capture['sharedFile'] for capture in captures
    }
    for capture in captures:
        shared = phase / 'fixture-window-images' / capture['sharedFile']
        assert shared.read_bytes() == Path(capture['originalExportPath']).read_bytes()
        assert hashlib.sha256(shared.read_bytes()).hexdigest() == capture['sha256']
    if phase_name in ['phone-both-global-qualified', 'phone-adaptive-qualified', 'mac-serialized-qualified', final_name]:
        names = [capture['suggestedHumanReadableName'] for capture in captures]
        assert any(name.startswith('Global completion overrides both saved List appearances_') for name in names)
    actual_log = gzip.decompress((phase / 'test.log.gz').read_bytes()).decode()
    assert ('** TEST SUCCEEDED **' in actual_log) == (failed_count == 0)

for phone_phase, tablet_phase in [
    ('phone-both-global-qualified', 'tablet-both-global-qualified'),
    ('phone-adaptive-qualified', 'tablet-adaptive-qualified'),
]:
    phone_products = json.loads((packet / phone_phase / 'product-sha256.json').read_text())
    tablet_before = json.loads((packet / tablet_phase / 'product-before-sha256.json').read_text())
    tablet_after = json.loads((packet / tablet_phase / 'product-sha256.json').read_text())
    assert phone_products == tablet_before == tablet_after
for phase_name in ['mac-serialized-qualified', final_name]:
    products = json.loads((packet / phase_name / 'product-sha256.json').read_text())
    assert len(products) == 3
    for product, expected_hash in products.items():
        assert hashlib.sha256(Path(product).read_bytes()).hexdigest() == expected_hash


def platform_lines(source, platform):
    active = True
    stack = []
    selected_lines = []
    for line in source.splitlines():
        directive = line.strip()
        if directive.startswith('#if '):
            condition = directive.removeprefix('#if ')
            assert condition in ['os(macOS)', 'os(iOS)']
            selected = condition == f'os({platform})'
            stack.append((active, selected))
            active = active and selected
        elif directive == '#else':
            parent, selected = stack[-1]
            active = parent and not selected
        elif directive == '#endif':
            active = stack.pop()[0]
        elif active and directive:
            selected_lines.append(directive)
    assert not stack
    return '\n'.join(selected_lines)


mac_source = gzip.decompress((packet / 'mac-serialized-qualified/SavedAppearanceJourneyTests.swift.gz').read_bytes()).decode()
current_source = (root / test_source).read_text()
assert platform_lines(mac_source, 'macOS') == platform_lines(current_source, 'macOS')
phone_source = gzip.decompress((packet / 'phone-adaptive-qualified/SavedAppearanceJourneyTests.swift.gz').read_bytes()).decode()
creation_start = current_source.index('    #else\n      if application.windows.firstMatch.frame.width > 600, !create.exists,', current_source.index('  private func createList('))
creation_end = current_source.index('    #endif', creation_start)
regular_width_controller = current_source[creation_start:creation_end]
phone_controller = '    #else\n      revealSidebarIfNeeded(application, element: create)\n      create.activateForPlannerJourney()\n'
assert current_source.replace(regular_width_controller, phone_controller, 1) == phone_source
inspection = json.loads((packet / 'visual-inspection.json').read_text())['files']
assert len(inspection) == 20
for entry in inspection:
    assert hashlib.sha256((packet / entry['file']).read_bytes()).hexdigest() == entry['sha256']
subprocess.run(['git', 'diff', '--exit-code', '37d479a', '--', 'Planner', 'PlannerFixtures', 'Packages', 'Configuration', 'Planner.xcodeproj'], cwd=root, check=True)
print('Verified ten 214-file source epochs, complete Mac/phone/tablet journeys, platform controller compatibility, recorded historical product reuse, current Mac/tablet products, 20 inspected native captures and unchanged production. Earlier controller and foreground failures remain separate.')
