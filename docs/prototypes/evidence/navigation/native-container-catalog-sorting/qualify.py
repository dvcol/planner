import gzip,hashlib,json,os,pathlib,subprocess
root=pathlib.Path.cwd()
assert root==pathlib.Path('/Users/dinh-van.colomban/Workspace/private/planner')
packet=root/'docs/prototypes/evidence/navigation/native-container-catalog-sorting'
for phase,device in [('phone-final-current','2A49C66C-C8A4-435F-B98A-9A90706780DE'),('tablet-final-current','FBD72DAB-1D40-4E64-912D-7F9763E00446')]:
 subprocess.run(['python3','/private/tmp/run-native-catalog-sort-cycle.py',phase,device],check=True)
 assert json.loads((packet/phase/'exit.json').read_text())['exitCode']==0
phase=packet/'mac-build';phase.mkdir(exist_ok=False)
sources=json.loads((packet/'tablet-final-current/source-sha256.json').read_text())
assert all(hashlib.sha256((root/source).read_bytes()).hexdigest()==digest for source,digest in sources.items())
(phase/'source-sha256.json').write_text(json.dumps(sources,indent=2)+'\n')
command=json.loads((root/'docs/prototypes/evidence/navigation/core-container-catalog-sorting/mac-build/command.json').read_text())
(phase/'command.json').write_text(json.dumps(command,indent=2)+'\n')
log=pathlib.Path('/private/tmp/PlannerNativeCatalogSort-mac-build.log')
with log.open('wb') as output:result=subprocess.run(command,cwd=root,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),stdout=output,stderr=subprocess.STDOUT)
(phase/'build.log.gz').write_bytes(gzip.compress(log.read_bytes(),mtime=0))
(phase/'exit.json').write_text(json.dumps({'exitCode':result.returncode,'UIRuntimeTests':0},indent=2)+'\n')
assert result.returncode==0,log.read_text()[-3000:]
products=[pathlib.Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures'),pathlib.Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtures.app/Contents/MacOS/PlannerFixtures.debug.dylib'),pathlib.Path('/private/tmp/PlannerRetainedRecoveryMacDerivedData/Build/Products/Debug/PlannerFixtureUITests-Runner.app/Contents/PlugIns/PlannerFixtureUITests.xctest/Contents/MacOS/PlannerFixtureUITests')]
for product in products:assert product.is_file(),product
(phase/'product-sha256.json').write_text(json.dumps({str(product):hashlib.sha256(product.read_bytes()).hexdigest() for product in products},indent=2)+'\n')
assert all(hashlib.sha256((root/source).read_bytes()).hexdigest()==digest for source,digest in sources.items())
print('Mac fixture app/testhost build passed; zero Mac UI runtime tests')
