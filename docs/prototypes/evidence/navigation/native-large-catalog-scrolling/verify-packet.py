import ast
import gzip
import hashlib
import json
from pathlib import Path

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-large-catalog-scrolling'
reference = json.loads((packet / 'phone-measured-swipes/source-sha256.json').read_text())
phases = sorted(path.parent for path in packet.glob('*/source-sha256.json'))
for phase in phases:
    hashes = json.loads((phase / 'source-sha256.json').read_text())
    for source, digest in hashes.items():
        if source.startswith(('Planner/', 'PlannerFixtures/', 'Packages/PlannerCore/Sources/')):
            assert reference[source] == digest, (phase.name, source)
    for snapshot in phase.glob('*.swift.gz'):
        candidates = [source for source in hashes if Path(source).name == snapshot.name[:-3]]
        assert len(candidates) == 1, snapshot
        assert hashlib.sha256(gzip.decompress(snapshot.read_bytes())).hexdigest() == hashes[candidates[0]], snapshot
    products = json.loads((phase / 'product-sha256.json').read_text())
    assert len(products) == 3, phase
    assert any(name.endswith('PlannerFixtures') for name in products), phase
    assert any(name.endswith('PlannerFixtures.debug.dylib') for name in products), phase
    assert any(name.endswith('PlannerFixtureUITests') for name in products), phase
for phase_name in ['tablet-hittable-checkpoints', 'mac-hittable-checkpoint-build']:
    phase = packet / phase_name
    assert json.loads((phase / 'exit.json').read_text())['exitCode'] == 0, phase
    for source, digest in json.loads((phase / 'source-sha256.json').read_text()).items():
        assert hashlib.sha256((root / source).read_bytes()).hexdigest() == digest, source
    for product, digest in json.loads((phase / 'product-sha256.json').read_text()).items():
        assert hashlib.sha256(Path(product).read_bytes()).hexdigest() == digest, product
for phase_name in ['phone-measured-swipes', 'tablet-hittable-checkpoints']:
    summary = json.loads((packet / phase_name / 'result-summary.json').read_text())
    assert summary['totalTestCount'] == 1 and summary['passedTests'] == 1 and summary['failedTests'] == 0, phase_name
for path in packet.rglob('*.json'):
    json.loads(path.read_text())
for path in packet.glob('*.py'):
    ast.parse(path.read_text())
for capture in json.loads((packet / 'capture-inspection.json').read_text())['captures']:
    assert capture['inspected']
    assert hashlib.sha256((packet / capture['file']).read_bytes()).hexdigest() == capture['sha256']
files = sorted(path for path in packet.rglob('*') if path.is_file() and path.name != 'artifacts-sha256.json')
manifest = {str(path.relative_to(packet)): hashlib.sha256(path.read_bytes()).hexdigest() for path in files}
(packet / 'artifacts-sha256.json').write_text(json.dumps(manifest, indent=2) + '\n')
assert all(hashlib.sha256((packet / path).read_bytes()).hexdigest() == digest for path, digest in manifest.items())
print('Verified', len(phases), 'source epochs, required products, original captures and', len(manifest), 'artifact hashes')
