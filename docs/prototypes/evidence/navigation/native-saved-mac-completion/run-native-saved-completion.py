import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
assert Path.cwd().resolve() == root
phase_name = sys.argv[1]
platform_name = sys.argv[2]
assert platform_name in ['mac', 'phone', 'tablet']
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-completion' / phase_name
packet.mkdir(parents=True, exist_ok=False)
tracked = subprocess.check_output(['git', 'ls-files', 'Planner', 'PlannerFixtures', 'PlannerFixtureUITests', 'PlannerNavigationUITests', 'Packages/PlannerCore/Sources', 'Planner.xcodeproj', 'Configuration'], text=True).splitlines()
sources = sorted({source for source in tracked if Path(source).suffix in ['.swift', '.pbxproj', '.xcscheme', '.xcconfig', '.plist', '.entitlements', '.resolved']})
hashes = {source: hashlib.sha256((root / source).read_bytes()).hexdigest() for source in sources}
(packet / 'source-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
for source in ['PlannerNavigationUITests/SavedAppearanceJourneyTests.swift', 'PlannerNavigationUITests/NativeNavigationElements.swift', 'Planner/Scenes/SavedPlannerView.swift']:
    (packet / (Path(source).name + '.gz')).write_bytes(gzip.compress((root / source).read_bytes(), mtime=0))
bundle = '/private/tmp/PlannerMacCompletion-' + phase_name + '.xcresult'
command = ['xcodebuild', 'test', '-project', 'Planner.xcodeproj', '-scheme', 'PlannerNavigation', '-destination', 'platform=macOS,arch=arm64', '-derivedDataPath', '/private/tmp/PlannerRetainedRecoveryMacDerivedData', '-clonedSourcePackagesDirPath', '/private/tmp/PlannerCalendarMonthSourcePackages', '-disableAutomaticPackageResolution', '-parallel-testing-enabled', 'NO', '-jobs', '1', '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '300', '-maximum-test-execution-time-allowance', '300', '-only-testing:PlannerNavigationUITests/SavedAppearanceJourneyTests/testListCompletionStaysLocalWhileGlobalCompletionOverridesAndReopeningRestoresIt', '-only-testing:PlannerNavigationUITests/SavedAppearanceJourneyTests/testListSelectionShowsContextualDetailsAndExplicitGlobalItemNavigation', '-resultBundlePath', bundle]
if platform_name != 'mac':
    destination = '2A49C66C-C8A4-435F-B98A-9A90706780DE' if platform_name == 'phone' else 'FBD72DAB-1D40-4E64-912D-7F9763E00446'
    command[command.index('-destination') + 1] = 'platform=iOS Simulator,id=' + destination
    command[command.index('-derivedDataPath') + 1] = '/private/tmp/PlannerCalendarTemporalDerivedData'
    command.append('CODE_SIGNING_ALLOWED=NO')
    if platform_name == 'tablet' and 'toolbar' not in phase_name:
        command[1] = 'test-without-building'
(packet / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
log = Path('/private/tmp/PlannerMacCompletion-' + phase_name + '.log')
if platform_name == 'tablet' and 'toolbar' not in phase_name:
    phone_log = Path('/private/tmp/PlannerMacCompletion-phone-adaptive-qualified.log').read_text()
    assert "Test Case '-[PlannerNavigationUITests.SavedAppearanceJourneyTests" in phone_log
    product_paths = [
        '/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/Planner.app/Planner',
        '/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/Planner.app/Planner.debug.dylib',
        '/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/PlannerNavigationUITests-Runner.app/PlugIns/PlannerNavigationUITests.xctest/PlannerNavigationUITests',
    ]
    before_products = {product: hashlib.sha256(Path(product).read_bytes()).hexdigest() for product in product_paths}
    (packet / 'product-before-sha256.json').write_text(json.dumps(before_products, indent=2) + '\n')
with log.open('wb') as output:
    result = subprocess.run(command, cwd=root, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'), stdout=output, stderr=subprocess.STDOUT)
(packet / 'test.log.gz').write_bytes(gzip.compress(log.read_bytes(), mtime=0))
(packet / 'exit.json').write_text(json.dumps({'exitCode': result.returncode, 'bundle': bundle}, indent=2) + '\n')
products = [
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/Planner.app/Contents/MacOS/Planner'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/Planner.app/Contents/MacOS/Planner.debug.dylib'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerNavigationUITests-Runner.app/Contents/PlugIns/PlannerNavigationUITests.xctest/Contents/MacOS/PlannerNavigationUITests'),
]
if platform_name != 'mac':
    products = [
        Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/Planner.app/Planner'),
        Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/Planner.app/Planner.debug.dylib'),
        Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/PlannerNavigationUITests-Runner.app/PlugIns/PlannerNavigationUITests.xctest/PlannerNavigationUITests'),
    ]
assert all(product.is_file() for product in products)
(packet / 'product-sha256.json').write_text(json.dumps({str(product): hashlib.sha256(product.read_bytes()).hexdigest() for product in products}, indent=2) + '\n')
assert all(hashlib.sha256((root / source).read_bytes()).hexdigest() == digest for source, digest in hashes.items())
print(phase_name, 'exit', result.returncode)
for line in log.read_text().splitlines():
    if line.startswith(('Test Case ', '** TEST', 'xcrun: error:')) or line.lstrip().startswith('Executed ') or ('.swift:' in line and ': error:' in line):
        print(line)
