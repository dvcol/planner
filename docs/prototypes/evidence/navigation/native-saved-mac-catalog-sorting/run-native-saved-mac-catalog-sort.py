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
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-catalog-sorting' / phase_name
packet.mkdir(parents=True, exist_ok=False)
tracked = subprocess.check_output(['git', 'ls-files', 'Planner', 'PlannerFixtures', 'PlannerFixtureUITests', 'PlannerNavigationUITests', 'Packages/PlannerCore/Sources', 'Planner.xcodeproj', 'Configuration'], text=True).splitlines()
sources = sorted({source for source in tracked if Path(source).suffix in ['.swift', '.pbxproj', '.xcscheme', '.xcconfig', '.plist', '.entitlements', '.resolved']})
hashes = {source: hashlib.sha256((root / source).read_bytes()).hexdigest() for source in sources}
(packet / 'source-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
for source in ['PlannerFixtureUITests/ContainerCatalogSortJourneyTests.swift', 'Planner/Scenes/SavedCatalogSort.swift', 'Planner/Scenes/SavedPlannerView.swift', 'Planner/Scenes/SavedItineraryViews.swift', 'PlannerNavigationUITests/NativeNavigationElements.swift']:
    (packet / (Path(source).name + '.gz')).write_bytes(gzip.compress((root / source).read_bytes(), mtime=0))
bundle = '/private/tmp/PlannerMacCatalogSort-' + phase_name + '.xcresult'
command = ['xcodebuild', 'test', '-project', 'Planner.xcodeproj', '-scheme', 'PlannerFixtures', '-destination', 'platform=macOS,arch=arm64', '-derivedDataPath', '/private/tmp/PlannerRetainedRecoveryMacDerivedData', '-clonedSourcePackagesDirPath', '/private/tmp/PlannerCalendarMonthSourcePackages', '-disableAutomaticPackageResolution', '-parallel-testing-enabled', 'NO', '-jobs', '1', '-test-timeouts-enabled', 'YES', '-default-test-execution-time-allowance', '300', '-maximum-test-execution-time-allowance', '300', '-only-testing:PlannerFixtureUITests/ContainerCatalogSortJourneyTests' + ('/' + sys.argv[2] if len(sys.argv) > 2 else ''), '-resultBundlePath', bundle]
(packet / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
log = Path('/private/tmp/PlannerMacCatalogSort-' + phase_name + '.log')
with log.open('wb') as output:
    result = subprocess.run(command, cwd=root, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'), stdout=output, stderr=subprocess.STDOUT)
(packet / 'test.log.gz').write_bytes(gzip.compress(log.read_bytes(), mtime=0))
(packet / 'exit.json').write_text(json.dumps({'exitCode': result.returncode, 'bundle': bundle}, indent=2) + '\n')
products = [
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures.debug.dylib'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtureUITests-Runner.app/Contents/PlugIns/PlannerFixtureUITests.xctest/Contents/MacOS/PlannerFixtureUITests'),
]
assert all(product.is_file() for product in products)
(packet / 'product-sha256.json').write_text(json.dumps({str(product): hashlib.sha256(product.read_bytes()).hexdigest() for product in products}, indent=2) + '\n')
assert all(hashlib.sha256((root / source).read_bytes()).hexdigest() == digest for source, digest in hashes.items())
print(phase_name, 'exit', result.returncode)
for line in log.read_text().splitlines():
    if line.startswith(('Test Case ', '** TEST', 'xcrun: error:')) or line.lstrip().startswith('Executed ') or ('.swift:' in line and ': error:' in line):
        print(line)
