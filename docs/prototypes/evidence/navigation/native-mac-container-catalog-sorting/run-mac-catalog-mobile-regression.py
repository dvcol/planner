import gzip,hashlib,json,os,pathlib,subprocess,sys
root=pathlib.Path.cwd()
assert root==pathlib.Path('/Users/dinh-van.colomban/Workspace/private/planner')
phase,device=sys.argv[1:3]
test_filter=sys.argv[3] if len(sys.argv)==4 else "PlannerFixtureUITests/ContainerCatalogSortJourneyTests"
packet=root/'docs/prototypes/evidence/navigation/native-mac-container-catalog-sorting'/phase
packet.mkdir(parents=True,exist_ok=False)
sources=['Planner/Scenes/SavedPlannerView.swift','Planner/Scenes/SavedPlannerStore.swift','Planner/Scenes/SavedItineraryViews.swift','PlannerFixtures/PlannerFixtureDataset.swift','PlannerFixtures/PlannerCatalogSortFixture.swift','PlannerFixtureUITests/ContainerCatalogSortJourneyTests.swift']
new_source=root/'Planner/Scenes/SavedCatalogSort.swift'
if phase in ('phone-red','phone-clean-red'):assert not new_source.exists()
else:sources.append(str(new_source.relative_to(root)))
hashes={source:hashlib.sha256((root/source).read_bytes()).hexdigest() for source in sources}
for source in sources:(packet/(pathlib.Path(source).name+'.gz')).write_bytes(gzip.compress((root/source).read_bytes(),mtime=0))
(packet/'source-sha256.json').write_text(json.dumps(hashes,indent=2)+'\n')
bundle='/private/tmp/PlannerMacCatalogSort-'+phase+'.xcresult'
command=['xcodebuild','test','-project','Planner.xcodeproj','-scheme','PlannerFixtures','-destination','platform=iOS Simulator,id='+device,'-derivedDataPath','/private/tmp/PlannerCalendarTemporalDerivedData','-clonedSourcePackagesDirPath','/private/tmp/PlannerCalendarMonthSourcePackages','-disableAutomaticPackageResolution','-parallel-testing-enabled','NO','-jobs','1','-only-testing:'+test_filter,'-resultBundlePath',bundle,'CODE_SIGNING_ALLOWED=NO']
(packet/'command.json').write_text(json.dumps(command,indent=2)+'\n')
log=pathlib.Path('/private/tmp/PlannerMacCatalogSort-'+phase+'.log')
with log.open('wb') as output:result=subprocess.run(command,cwd=root,env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer'),stdout=output,stderr=subprocess.STDOUT)
(packet/'test.log.gz').write_bytes(gzip.compress(log.read_bytes(),mtime=0))
products=[pathlib.Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtures.app/PlannerFixtures'),pathlib.Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtures.app/PlannerFixtures.debug.dylib'),pathlib.Path('/private/tmp/PlannerCalendarTemporalDerivedData/Build/Products/Debug-iphonesimulator/PlannerFixtureUITests-Runner.app/PlugIns/PlannerFixtureUITests.xctest/PlannerFixtureUITests')]
for product in products:assert product.is_file(),product
(packet/'product-sha256.json').write_text(json.dumps({str(product):hashlib.sha256(product.read_bytes()).hexdigest() for product in products},indent=2)+'\n')
assert hashes=={source:hashlib.sha256((root/source).read_bytes()).hexdigest() for source in sources}
(packet/'exit.json').write_text(json.dumps({'exitCode':result.returncode,'bundle':bundle},indent=2)+'\n')
print(phase,'exit',result.returncode)
for line in log.read_text().splitlines():
 if any(term in line for term in ('error:','Executed ','Test Case ','** TEST')):print(line)
