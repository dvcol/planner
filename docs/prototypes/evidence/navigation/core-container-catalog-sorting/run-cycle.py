import gzip
import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile
import uuid

root = pathlib.Path.cwd()
assert (root / 'Packages/PlannerCore/Package.swift').is_file()
phase, test_filter = sys.argv[1:]
packet = root / 'docs/prototypes/evidence/navigation/core-container-catalog-sorting' / phase
packet.mkdir(parents=True, exist_ok=False)
sources = [
    'Packages/PlannerCore/Sources/PlannerCore/PlannerValues.swift',
    'Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift',
    'Packages/PlannerCore/Tests/PlannerCoreStoreTests/ContainerCatalogSortTests.swift',
]
source_hashes = {source: hashlib.sha256((root / source).read_bytes()).hexdigest() for source in sources}
for source in sources:
    (packet / (pathlib.Path(source).name + '.gz')).write_bytes(gzip.compress((root / source).read_bytes(), mtime=0))
(packet / 'source-sha256.json').write_text(json.dumps(source_hashes, indent=2) + '\n')
command = ['xcrun', 'swift', 'test', '--package-path', 'Packages/PlannerCore', '--scratch-path', '/private/tmp/PlannerLargeCollectionCoreBuild', '--filter', test_filter, '--jobs', '1']
(packet / 'command.json').write_text(json.dumps(command, indent=2) + '\n')
log_path = pathlib.Path('/private/tmp/PlannerContainerCatalog-' + phase + '.log')
with log_path.open('wb') as log:
    result = subprocess.run(command, cwd=root, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'), stdout=log, stderr=subprocess.STDOUT)
(packet / 'test.log.gz').write_bytes(gzip.compress(log_path.read_bytes(), mtime=0))
product = pathlib.Path('/private/tmp/PlannerLargeCollectionCoreBuild/out/Products/Debug/PlannerCoreStoreTests.xctest/Contents/MacOS/PlannerCoreStoreTests')
(packet / 'product-sha256.json').write_text(json.dumps({str(product): hashlib.sha256(product.read_bytes()).hexdigest()}, indent=2) + '\n')
assert source_hashes == {source: hashlib.sha256((root / source).read_bytes()).hexdigest() for source in sources}
(packet / 'exit.json').write_text(json.dumps({'exitCode': result.returncode, 'filter': test_filter}, indent=2) + '\n')
fixtures = re.findall(r'^Container catalog sort fixture: (.+)$', log_path.read_text(), re.MULTILINE)
assert len(fixtures) == len(set(fixtures))
cleanup = []
expected_parent = pathlib.Path(tempfile.gettempdir()).resolve() / 'PlannerContainerCatalogSortTests'
for fixture_path in fixtures:
    directory = pathlib.Path(fixture_path).resolve()
    assert directory.parent == expected_parent
    assert str(uuid.UUID(directory.name)) == directory.name.lower()
    store_exists = (directory / 'store/Planner.sqlite').is_file()
    removed = False
    if result.returncode == 0:
        assert store_exists
        shutil.rmtree(directory)
        assert not directory.exists()
        removed = True
    cleanup.append({'directory': str(directory), 'storeExistedAfterProcessExit': store_exists, 'removedAfterSuccessfulProcessExit': removed})
(packet / 'cleanup.json').write_text(json.dumps(cleanup, indent=2) + '\n')
print(phase, 'exit', result.returncode)
print(log_path.read_text()[-1800:])
