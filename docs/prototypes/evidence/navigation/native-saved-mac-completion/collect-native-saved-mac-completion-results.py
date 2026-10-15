import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

root = Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet = root / 'docs/prototypes/evidence/navigation/native-saved-mac-completion'
for name in sys.argv[1:]:
    phase = packet / name
    bundle = json.loads((phase / 'exit.json').read_text())['bundle']
    command = ['xcrun', 'xcresulttool', 'get', 'test-results', 'summary', '--path', bundle]
    result = subprocess.run(command, env=dict(os.environ, DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'), capture_output=True)
    assert result.returncode == 0, result.stderr.decode()
    original = Path('/private/tmp/PlannerMacCompletion-' + name + '-original-summary.json')
    original.write_bytes(result.stdout)
    summary = json.loads(result.stdout)
    if name == 'mac-native-probe':
        scoped = {key: summary[key] for key in ['title', 'environmentDescription', 'totalTestCount', 'passedTests', 'failedTests', 'skippedTests', 'startTime', 'finishTime', 'testResults'] if key in summary}
        scoped['failureHeadlines'] = [failure.get('failureText', '').splitlines()[0] for failure in summary.get('testFailures', [])]
        (phase / 'result-summary-scoped.json').write_text(json.dumps(scoped, indent=2) + '\n')
        (phase / 'summary-scope.json').write_text(json.dumps({'originalLocalPath': str(original), 'originalSHA256': hashlib.sha256(result.stdout).hexdigest(), 'scope': 'Summary counts and first assertion headline only; full failure hierarchies omitted because they include unrelated system menus.'}, indent=2) + '\n')
    else:
        (phase / 'result-summary.json').write_bytes(result.stdout)
    (phase / 'summary-command.json').write_text(json.dumps(command, indent=2) + '\n')
    print(name, 'total', summary.get('totalTestCount'), 'passed', summary.get('passedTests'), 'failed', summary.get('failedTests'))
