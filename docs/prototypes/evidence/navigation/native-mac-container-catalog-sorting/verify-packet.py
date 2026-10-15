import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-mac-container-catalog-sorting'
source_name = 'PlannerFixtureUITests/ContainerCatalogSortJourneyTests.swift'
source_bytes = (root / source_name).read_bytes()
assert source_bytes == subprocess.check_output(['git', 'show', 'HEAD:' + source_name], cwd=root)
with tempfile.TemporaryDirectory(prefix='PlannerMacCatalogDraft-', dir='/private/tmp') as directory:
    destination = Path(directory) / source_name
    destination.parent.mkdir(parents=True)
    destination.write_bytes(source_bytes)
    subprocess.run(['git', 'apply', '-'], input=gzip.decompress((packet / 'unqualified-mac-adapter.patch.gz').read_bytes()), cwd=directory, check=True)
    assert destination.read_bytes() == gzip.decompress((packet / 'final-unqualified-adapter.swift.gz').read_bytes())
phases = sorted(path for path in packet.iterdir() if path.is_dir())
for phase in phases:
    sources = json.loads((phase / 'source-sha256.json').read_text())
    for source, expected in sources.items():
        if source != source_name:
            assert hashlib.sha256((root / source).read_bytes()).hexdigest() == expected, (phase.name, source)
    snapshot = gzip.decompress((phase / 'ContainerCatalogSortJourneyTests.swift.gz').read_bytes())
    assert hashlib.sha256(snapshot).hexdigest() == sources[source_name]
    summary_path = phase / ('result-summary-scoped.json' if phase.name == 'mac-native-probe' else 'result-summary.json')
    summary = json.loads(summary_path.read_text())
    if phase.name == 'phone-adapter-regression':
        assert summary['passedTests'] == 2 and summary['failedTests'] == 0 and summary['skippedTests'] == 0
    else:
        assert summary['passedTests'] == 0 and summary['failedTests'] > 0
    logs = list(phase.glob('*log.gz'))
    assert len(logs) == 1
    text = gzip.decompress(logs[0].read_bytes()).decode()
    assert 'Recent Documents' not in text and 'Recent Applications' not in text
first = packet / 'mac-native-probe'
assert not (first / 'test.log.gz').exists()
scope = json.loads((first / 'log-scope.json').read_text())
assert (first / 'test-app-window-scope.log.gz').is_file()
print('Verified', len(phases), 'source epochs; canonical test unchanged; draft patch reproduces exact final draft; diagnostic and compatibility outcomes remain separate.')
