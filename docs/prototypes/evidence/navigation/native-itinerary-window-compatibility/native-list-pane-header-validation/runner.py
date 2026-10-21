from pathlib import Path
import hashlib,json,os,subprocess
repository=Path("/Users/dinh-van.colomban/Workspace/private/planner")
assert Path.cwd().resolve()==repository
parent=repository/"docs/prototypes/evidence/navigation/native-itinerary-window-compatibility"
packet=parent/"native-list-pane-header-validation"
packet.mkdir(exist_ok=False)
snapshots=[]
for name in ["native-list-pane-header-final-mac-build","native-list-pane-header-sort-native-mac-build","native-list-pane-header-phone","native-list-pane-header-tablet"]:
    source=parent/name/"source-sha256.json"
    hashes=json.loads(source.read_text())
    checked=0
    for relative,digest in hashes.items():
        if not relative.startswith(("Planner/","Packages/","Configuration/","Planner.xcodeproj/","PlannerShareMobile/","PlannerShareMac/")):continue
        current=repository/relative
        assert current.is_file() and hashlib.sha256(current.read_bytes()).hexdigest()==digest,relative
        checked+=1
    assert checked>0
    snapshots.append({"packet":name,"productionInputsMatchCurrent":True,"checkedInputCount":checked,"sourceSnapshotSha256":hashlib.sha256(source.read_bytes()).hexdigest()})
cases=[]
for name,expected in [("native-list-pane-header-final-mac",3),("native-list-pane-header-sort-native-mac",1),("native-list-pane-header-phone",1),("native-list-pane-header-tablet",1)]:
    summary=json.loads((parent/name/"test-results-summary.json").read_text())
    assert summary["totalTestCount"]==expected and summary["passedTests"]==expected and summary["failedTests"]==0 and summary["skippedTests"]==0
    assert json.loads((parent/name/"exit.json").read_text())["exitCode"]==0
    cases.append({"packet":name,"passedTests":expected,"failedTests":0,"skippedTests":0})
swift_files=["Planner/Scenes/SavedItemFilters.swift","Planner/Scenes/SavedMacMembershipTable.swift","Planner/Scenes/SavedNewItemForm.swift","Planner/Scenes/SavedOwnedLinksEditor.swift","Planner/Scenes/SavedPlannerView.swift","PlannerNavigationUITests/SavedAppearanceJourneyTests.swift"]
markdown_files=["docs/prototypes/native-list-pane-header.md","docs/prototypes/native-local-storage-cleanup.md","docs/native-ui-polish.md","docs/open-decisions.md"]
commands=[
["xcrun","swift-format","lint","--strict",*swift_files],
["pnpm","dlx","markdownlint-cli2@0.23.3","--config","docs/prototypes/evidence/navigation/native-empty-recovery-graph/markdownlint.jsonc",*markdown_files],
["git","diff","--check"]]
checks=[]
for command in commands:
    result=subprocess.run(command,cwd=repository,env=dict(os.environ,DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"),capture_output=True,text=True)
    checks.append({"command":command,"exitCode":result.returncode,"stdout":result.stdout,"stderr":result.stderr})
    assert result.returncode==0,result.stdout+result.stderr
report={"sourceReconciliation":snapshots,"nativeResults":cases,"checks":checks,"reviewedFilesSha256":{relative:hashlib.sha256((repository/relative).read_bytes()).hexdigest() for relative in swift_files+markdown_files},"limits":"Focused native UI qualification only. No physical, signed-storage, system Intent, complete accessibility or whole-app release acceptance."}
(packet/"validation.json").write_text(json.dumps(report,indent=2)+"\n")
(packet/"runner.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"passingNativeCases":sum(record["passedTests"] for record in cases),"sourceEpochsReconciled":len(snapshots),"checks":[record["exitCode"] for record in checks]}))
