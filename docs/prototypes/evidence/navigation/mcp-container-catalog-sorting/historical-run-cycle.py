import gzip,hashlib,json,os,pathlib,re,shutil,subprocess,sys,uuid
root=pathlib.Path.cwd()
assert root==pathlib.Path('/Users/dinh-van.colomban/Workspace/private/planner')
phase=sys.argv[1]
packet=root/'docs/prototypes/evidence/navigation/mcp-container-catalog-sorting'/phase
packet.mkdir(parents=True,exist_ok=False)
sources=['Planner/AgentControl/PlannerMCPQueryTool.swift','PlannerMCPTests/ContainerCatalogSortRoutingTests.swift','Packages/PlannerCore/Sources/PlannerCore/PlannerCore.swift','Packages/PlannerCore/Sources/PlannerCore/PlannerValues.swift']
hashes={source:hashlib.sha256((root/source).read_bytes()).hexdigest() for source in sources}
for source in sources:(packet/(pathlib.Path(source).name+'.gz')).write_bytes(gzip.compress((root/source).read_bytes(),mtime=0))
(packet/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
bundle='/private/tmp/PlannerCatalogSortHTTP-'+phase+'.xcresult'
command=['xcodebuild','-project','Planner.xcodeproj','-scheme','Planner','-destination','platform=macOS,arch=arm64','-derivedDataPath','/private/tmp/PlannerMCPDerivedData','-clonedSourcePackagesDirPath','/private/tmp/PlannerMCPSourcePackages','-disableAutomaticPackageResolution','-parallel-testing-enabled','NO','-jobs','1','-only-testing:PlannerMCPTests/ContainerCatalogSortRoutingTests','-resultBundlePath',bundle,'CODE_SIGNING_ALLOWED=NO','test']
(packet/'command.json').write_text(json.dumps(command,indent=2)+'\n')
log_path=pathlib.Path('/private/tmp/PlannerCatalogSortHTTP-'+phase+'.log')
with log_path.open('wb') as log:result=subprocess.run(command,cwd=root,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),stdout=log,stderr=subprocess.STDOUT)
(packet/'test.log.gz').write_bytes(gzip.compress(log_path.read_bytes(),mtime=0))
products=[pathlib.Path('/private/tmp/PlannerMCPDerivedData/Build/Products/Debug/Planner.app/Contents/MacOS/Planner'),pathlib.Path('/private/tmp/PlannerMCPDerivedData/Build/Products/Debug/PlannerMCPTests.xctest/Contents/MacOS/PlannerMCPTests')]
(packet/'product-sha256.json').write_text(json.dumps({str(product):hashlib.sha256(product.read_bytes()).hexdigest() for product in products if product.is_file()},indent=2)+'\n')
assert hashes=={source:hashlib.sha256((root/source).read_bytes()).hexdigest() for source in sources}
(packet/'exit.json').write_text(json.dumps({'exitCode':result.returncode,'bundle':bundle},indent=2)+'\n')
fixtures=re.findall(r'^Container catalog HTTP fixture: (.+)$',log_path.read_text(),re.MULTILINE)
cleanup=[]
for fixture in fixtures:
 directory=pathlib.Path(fixture).resolve()
 assert directory.parent.name=='PlannerContainerCatalogHTTPTests'
 assert str(uuid.UUID(directory.name))==directory.name.lower()
 assert str(directory).startswith('/private/var/folders/')
 exists=(directory/'store/Planner.sqlite').is_file()
 removed=False
 if result.returncode==0:
  assert exists;shutil.rmtree(directory);assert not directory.exists();removed=True
 cleanup.append({'directory':str(directory),'storeExistedAfterProcessExit':exists,'removedAfterSuccessfulProcessExit':removed})
(packet/'cleanup.json').write_text(json.dumps(cleanup,indent=2)+'\n')
print(phase,'exit',result.returncode,'fixtures',len(fixtures))
print(log_path.read_text()[-4200:])
