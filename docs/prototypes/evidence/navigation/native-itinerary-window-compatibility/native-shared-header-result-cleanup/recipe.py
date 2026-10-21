from pathlib import Path
import gzip,hashlib,json,os,shutil,subprocess
repository=Path('/Users/dinh-van.colomban/Workspace/private/planner')
assert Path.cwd().resolve()==repository
rows=json.loads(Path('/private/tmp/PlannerVerifiedHeaderResultCleanupPlan.json').read_text())
environment=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
open_files=subprocess.run(['lsof','-nP','-Fpn'],capture_output=True,text=True)
assert open_files.returncode in [0,1],open_files.returncode
for row in rows:
 packet=repository/row['packet']
 bundle=Path(row['bundle'])
 assert bundle.parent==Path('/private/tmp') and not bundle.is_symlink() and bundle.is_dir()
 assert bundle.name.startswith('PlannerItemWindow-native-list-') and bundle.name.endswith('.xcresult')
 assert str(bundle) not in open_files.stdout,'Result is in use: '+str(bundle)
 command=json.loads((packet/'command.json').read_text())
 assert command[command.index('-resultBundlePath')+1]==str(bundle)
 subprocess.run(['git','diff','--exit-code','HEAD','--',str(packet)],check=True,capture_output=True)
 for name,digest in row['retainedSha256'].items():
  assert hashlib.sha256((packet/name).read_bytes()).hexdigest()==digest,(packet,name)
 for attachment in json.loads((packet/'selected-attachments.json').read_text())['attachments']:
  filename=attachment['retainedFileName']
  content=(packet/filename).read_bytes()
  if filename.endswith('.gz'):content=gzip.decompress(content)
  assert hashlib.sha256(content).hexdigest()==attachment['sha256'],(packet,filename)
 summary=json.loads(subprocess.check_output(['xcrun','xcresulttool','get','test-results','summary','--path',str(bundle)],env=environment))
 assert summary==json.loads((packet/'test-results-summary.json').read_text()),bundle
 row['rawSummaryMatchesRetained']=True
 row['openFileExcluded']=True
before=shutil.disk_usage('/private/tmp').free
for row in rows:
 shutil.rmtree(row['bundle'])
 row['removed']=not Path(row['bundle']).exists()
 assert row['removed'],row['bundle']
after=shutil.disk_usage('/private/tmp').free
packet=repository/'docs/prototypes/evidence/navigation/native-itinerary-window-compatibility/native-shared-header-result-cleanup'
packet.mkdir(exist_ok=False)
report={'date':'2026-10-21','completedBundles':len(rows),'nominalAllocatedBytesRemoved':sum(row['bytes'] for row in rows),'freeBytesBefore':before,'freeBytesAfter':after,'freeSpaceCaveat':'Concurrent APFS activity and shared allocation also affect free space.','retainedOriginalAttachments':sum(row['verifiedRetainedAttachments'] for row in rows),'retainedGitCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'rows':rows}
(packet/'reclamation.json').write_text(json.dumps(report,indent=2)+'\n')
(packet/'recipe.py').write_bytes(Path(__file__).read_bytes())
print('Removed',len(rows),'completed committed raw bundles;',report['nominalAllocatedBytesRemoved'],'nominal bytes; retained',report['retainedOriginalAttachments'],'hash-verified original attachments.')
