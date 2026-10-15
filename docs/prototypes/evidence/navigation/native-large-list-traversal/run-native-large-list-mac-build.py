import gzip
import hashlib
import json
import os
from pathlib import Path
import subprocess

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
assert Path.cwd().resolve() == root
packet = root / 'docs/prototypes/evidence/navigation/native-large-list-traversal/mac-build'
packet.mkdir(exist_ok=False)
phone_phase = packet.parent / 'phone-row-snapshots'
hashes = json.loads((phone_phase / 'source-sha256.json').read_text())
assert all(hashlib.sha256((root / source).read_bytes()).hexdigest() == digest for source, digest in hashes.items())
(packet / 'source-sha256.json').write_text(json.dumps(hashes, indent=2) + '\n')
command = json.loads((root / 'docs/prototypes/evidence/navigation/core-container-catalog-sorting/mac-build/command.json').read_text())
(packet / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
log = Path('/private/tmp/PlannerLargeListTraversalMacBuild.log')
with log.open('wb') as output:
    result = subprocess.run(command, cwd=root, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'), stdout=output, stderr=subprocess.STDOUT)
(packet / 'build.log.gz').write_bytes(gzip.compress(log.read_bytes(), mtime=0))
(packet / 'exit.json').write_text(json.dumps({'exitCode': result.returncode, 'runtimeTests': 0}, indent=2) + '\n')
products = [
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures.debug.dylib'),
    Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtureUITests-Runner.app/Contents/PlugIns/PlannerFixtureUITests.xctest/Contents/MacOS/PlannerFixtureUITests'),
]
assert all(product.is_file() for product in products)
(packet / 'product-sha256.json').write_text(json.dumps({str(product): hashlib.sha256(product.read_bytes()).hexdigest() for product in products}, indent=2) + '\n')
assert all(hashlib.sha256((root / source).read_bytes()).hexdigest() == digest for source, digest in hashes.items())
print('Mac build exit', result.returncode)
for line in log.read_text().splitlines():
    if line.startswith('** TEST') or ('.swift:' in line and ': error:' in line):
        print(line)
