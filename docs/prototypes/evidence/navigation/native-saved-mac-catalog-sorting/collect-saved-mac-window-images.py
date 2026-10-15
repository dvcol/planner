import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-catalog-sorting'
manual_titles = [
    'Lists sorted by full estimate descending with incomplete plans last',
    'Itineraries keep their separate full estimate ascending choice',
    'A separate local dataset starts with alphabetical catalog defaults',
    'Returning to the original dataset restores both catalog choices',
    'Sorting the visible List catalog retains the selected Zulu plan contents',
    'Removing a shared Item estimate moves its List into the incomplete group',
    'A shared Item edit preserves the Itineraries own Last updated order',
    'The final sort and archive choice publishes one consistent catalog',
    'Native estimate editor before toggling',
]
for phase_name in sys.argv[1:]:
    phase = packet / phase_name
    bundle = json.loads((phase / 'exit.json').read_text())['bundle']
    original_directory = Path(tempfile.mkdtemp(prefix='PlannerSavedMacImages-' + phase_name + '-', dir='/private/tmp'))
    command = ['xcrun', 'xcresulttool', 'export', 'attachments', '--path', bundle, '--output-path', str(original_directory), '--filter', '*.png']
    result = subprocess.run(command, capture_output=True, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'))
    (original_directory / 'export.stdout').write_bytes(result.stdout)
    (original_directory / 'export.stderr').write_bytes(result.stderr)
    assert result.returncode == 0, result.stderr.decode()
    original_manifest = original_directory / 'manifest.json'
    records = []
    destination_directory = phase / 'fixture-window-images'
    destination_directory.mkdir(exist_ok=False)
    for test in json.loads(original_manifest.read_text()):
        for attachment in test['attachments']:
            name = attachment['suggestedHumanReadableName']
            if not any(name.startswith(title + '_') for title in manual_titles):
                continue
            original = original_directory / attachment['exportedFileName']
            destination = destination_directory / original.name
            shutil.copyfile(original, destination)
            assert original.read_bytes() == destination.read_bytes()
            records.append(dict(attachment, testIdentifier=test['testIdentifier'], originalExportPath=str(original), sharedFile=original.name, sha256=hashlib.sha256(original.read_bytes()).hexdigest()))
    (phase / 'fixture-window-capture-manifest.json').write_text(json.dumps(records, indent=2) + '\n')
    (phase / 'image-export-scope.json').write_text(json.dumps({'command':command,'originalManifestLocalPath':str(original_manifest),'originalManifestSHA256':hashlib.sha256(original_manifest.read_bytes()).hexdigest(),'scope':'Only explicitly named manual fixture-window captures copied unchanged. Automatic desktop/failure images, if present, remain local and receive no shared visual credit.'}, indent=2) + '\n')
    print(phase_name, 'manual window PNGs', len(records))
    for record in records:
        print(record['suggestedHumanReadableName'], str(destination_directory / record['sharedFile']))
