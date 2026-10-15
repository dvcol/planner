import json,os,pathlib,subprocess,sys
root=pathlib.Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet=root/'docs/prototypes/evidence/navigation/native-large-list-traversal'
for name in sys.argv[1:]:
 phase=packet/name
 bundle=json.loads((phase/'exit.json').read_text())['bundle']
 commands={}
 for action,arguments in [('summary',['get','test-results','summary','--path',bundle]),('attachments',['export','attachments','--path',bundle,'--output-path',str(phase/'attachments'),'--filter','*.png']),('identities',['export','attachments','--path',bundle,'--output-path',str(phase/'identity-attachments'),'--filter','*.txt'])]:
  command=['xcrun','xcresulttool']+arguments
  commands[action]=command
  result=subprocess.run(command,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),capture_output=True)
  (phase/(action+'.stdout')).write_bytes(result.stdout)
  (phase/(action+'.stderr')).write_bytes(result.stderr)
  assert result.returncode==0,result.stderr.decode()
  if action=='summary':(phase/'result-summary.json').write_bytes(result.stdout)
 (phase/'inspection-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
 summary=json.loads((phase/'result-summary.json').read_text())
 print(name,summary.get('totalTestCount'),summary.get('passedTests'),summary.get('failedTests'),'PNGs',len(list((phase/'attachments').glob('*.png'))))
