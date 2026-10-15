import gzip,hashlib,json,os,pathlib,subprocess,sys
root=pathlib.Path.cwd()
assert root==pathlib.Path('/Users/dinh-van.colomban/Workspace/private/planner')
phase,device=sys.argv[1:3]
packet=root/'docs/prototypes/evidence/navigation/native-large-catalog-scrolling'/phase
packet.mkdir(parents=True,exist_ok=False)
tracked=subprocess.check_output(['git','ls-files','Planner','PlannerFixtures','PlannerFixtureUITests','Packages/PlannerCore/Sources','Planner.xcodeproj'],text=True).splitlines()
sources=[source for source in tracked if pathlib.Path(source).suffix in ['.swift','.pbxproj','.xcscheme','.xcconfig','.plist','.entitlements']]
sources.append('PlannerFixtureUITests/LargeCollectionScrollDiagnosticTests.swift')
hashes={source:hashlib.sha256((root/source).read_bytes()).hexdigest() for source in sorted(set(sources))}
(packet/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
for source in ['PlannerFixtureUITests/LargeCollectionScrollDiagnosticTests.swift','PlannerFixtures/PlannerFixtureDataset.swift','Planner/Scenes/SavedPlannerStore.swift','Planner/Scenes/SavedPlannerView.swift','Planner/Scenes/SavedItemViews.swift']:
 (packet/(pathlib.Path(source).name+'.gz')).write_bytes(gzip.compress((root/source).read_bytes(),mtime=0))
bundle='/private/tmp/PlannerLargeCatalogScroll-'+phase+'.xcresult'
command=['xcodebuild','test','-project','Planner.xcodeproj','-scheme','PlannerFixtures','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath','/private/tmp/PlannerLargeScrollDiagnosticDerivedData','-clonedSourcePackagesDirPath','/private/tmp/PlannerCalendarMonthSourcePackages','-disableAutomaticPackageResolution','-parallel-testing-enabled','NO','-jobs','1','-only-testing:PlannerFixtureUITests/LargeCollectionScrollDiagnosticTests','-resultBundlePath',bundle,'CODE_SIGNING_ALLOWED=NO']
(packet/'command.json').write_text(json.dumps(command,indent=2)+'\n')
log=pathlib.Path('/private/tmp/PlannerLargeCatalogScroll-'+phase+'.log')
with log.open('wb') as output:result=subprocess.run(command,cwd=root,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),stdout=output,stderr=subprocess.STDOUT)
(packet/'test.log.gz').write_bytes(gzip.compress(log.read_bytes(),mtime=0))
(packet/'exit.json').write_text(json.dumps({'exitCode':result.returncode,'bundle':bundle},indent=2)+'\n')
products=[pathlib.Path('/private/tmp/PlannerLargeScrollDiagnosticDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtures.app/PlannerFixtures'),pathlib.Path('/private/tmp/PlannerLargeScrollDiagnosticDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtures.app/PlannerFixtures.debug.dylib'),pathlib.Path('/private/tmp/PlannerLargeScrollDiagnosticDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtureUITests-Runner.app/PlugIns/PlannerFixtureUITests.xctest/PlannerFixtureUITests')]
for product in products:assert product.is_file(),product
(packet/'product-sha256.json').write_text(json.dumps({str(product):hashlib.sha256(product.read_bytes()).hexdigest() for product in products},indent=2)+'\n')
assert all(hashlib.sha256((root/source).read_bytes()).hexdigest()==digest for source,digest in hashes.items())
print(phase,'exit',result.returncode)
for line in log.read_text().splitlines():
 if line.startswith(('Test Case ','** TEST','xcrun: error:')) or line.lstrip().startswith('Executed ') or ('.swift:' in line and ': error:' in line):print(line)
