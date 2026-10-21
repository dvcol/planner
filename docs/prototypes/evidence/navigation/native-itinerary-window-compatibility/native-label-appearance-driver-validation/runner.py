from pathlib import Path
import difflib,gzip,hashlib,json,os,re,subprocess
repository=Path("/Users/dinh-van.colomban/Workspace/private/planner")
assert Path.cwd().resolve()==repository
parent=repository/"docs/prototypes/evidence/navigation/native-itinerary-window-compatibility"
packet=parent/"native-label-appearance-driver-validation"
packet.mkdir(exist_ok=True)
for comparison in packet.glob("*.test-source-diff.txt"):comparison.unlink()
current_test=repository/"PlannerNavigationUITests/SavedCategoryJourneyTests.swift"
current_text=current_test.read_text()
common_names=[
"testCategoryColorStagesSaveCancelAndClearAcrossRelaunch",
"testCategoryCreationAndRenameStageCancelAndPersistAfterRelaunch",
"testCategoryIconStagesCancelAndPersistsIndependentIconEditsAfterRelaunch"]
rgb_name="testNativeColorPickerEditsPersistAcrossSaveAndRelaunch"
def method_text(content,name):
    start=content.index("func "+name+"(")
    opening=content.index("{",start)
    depth=0
    for position in range(opening,len(content)):
        if content[position]=="{":depth+=1
        if content[position]=="}":depth-=1
        if depth==0:return content[start:position+1]
    raise AssertionError(name)
epoch_records=[]
for name in ["native-label-appearance-mac-driver-build","native-label-appearance-driver-phone","native-label-appearance-driver-tablet","native-label-rgb-popover-tablet","native-label-rgb-sheet-phone"]:
    epoch=parent/name
    hashes=json.loads((epoch/"source-sha256.json").read_text())
    checked=0
    for relative,digest in hashes.items():
        if not relative.startswith(("Planner/","Packages/","Configuration/","Planner.xcodeproj/","PlannerShareMobile/","PlannerShareMac/")):continue
        path=repository/relative
        assert path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==digest,relative
        checked+=1
    test_bytes=gzip.decompress((epoch/"SavedCategoryJourneyTests.swift.gz").read_bytes())
    frozen_text=test_bytes.decode()
    for method in common_names+["categoryRow","newCategory","openCategories","replaceText","recordScreenshot"]:
        assert method_text(frozen_text,method)==method_text(current_text,method),(name,method)
    test_matches=test_bytes==current_test.read_bytes()
    if name.startswith("native-label-rgb-"):assert test_matches
    if not test_matches:
        (packet/(name+".test-source-diff.txt.gz")).write_bytes(gzip.compress("".join(difflib.unified_diff(frozen_text.splitlines(keepends=True),current_text.splitlines(keepends=True),fromfile=name,tofile="current")).encode(),mtime=0))
    epoch_records.append({"packet":name,"productionConfigurationInputsMatch":True,"checkedInputCount":checked,"commonCasesAndHelpersByteIdentical":True,"entireCategoryTestFileMatchesCurrent":test_matches})
runs=[
("native-label-appearance-mac-driver-qualified","mac",3,3,0,common_names),
("native-label-appearance-driver-phone","phone",4,4,0,common_names+[rgb_name]),
("native-label-appearance-driver-tablet","tablet",4,3,1,common_names),
("native-label-rgb-popover-tablet","tablet",1,1,0,[rgb_name]),
("native-label-rgb-sheet-phone","phone",1,1,0,[rgb_name])]
platform_cases={}
run_records=[]
verified_attachments=0
for name,platform,total,passed,failed,expected_cases in runs:
    epoch=parent/name
    summary=json.loads((epoch/"test-results-summary.json").read_text())
    assert (summary["totalTestCount"],summary["passedTests"],summary["failedTests"],summary["skippedTests"])==(total,passed,failed,0),name
    outcome=json.loads((epoch/"exit.json").read_text())
    assert outcome["exitCode"]==(65 if failed else 0),name
    log=gzip.decompress((epoch/"test.log.gz").read_bytes()).decode(errors="replace")
    observed=set(re.findall(r"Test Case '-\[PlannerNavigationUITests\.SavedCategoryJourneyTests ([^\]]+)\]' passed \(",log))
    assert observed==set(expected_cases),(name,sorted(observed))
    platform_cases.setdefault(platform,set()).update(observed)
    attachments=json.loads((epoch/"selected-attachments.json").read_text())["attachments"]
    for attachment in attachments:
        path=epoch/attachment["retainedFileName"]
        content=path.read_bytes()
        if path.suffix==".gz":content=gzip.decompress(content)
        assert hashlib.sha256(content).hexdigest()==attachment["sha256"],str(path)
        verified_attachments+=1
    run_records.append({"packet":name,"exitCode":outcome["exitCode"],"passingCaseNames":sorted(observed),"failedTests":failed,"skippedTests":0})
assert len(platform_cases["mac"])==3 and len(platform_cases["phone"])==4 and len(platform_cases["tablet"])==4
commands=[
["xcrun","swift-format","lint","--strict","PlannerNavigationUITests/SavedCategoryJourneyTests.swift"],
["pnpm","dlx","markdownlint-cli2@0.23.3","--config","docs/prototypes/evidence/navigation/native-empty-recovery-graph/markdownlint.jsonc","docs/prototypes/native-label-appearance.md","docs/open-decisions.md"],
["git","diff","--check"]]
checks=[]
for command in commands:
    result=subprocess.run(command,cwd=repository,env=dict(os.environ,DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"),capture_output=True,text=True)
    checks.append({"command":command,"exitCode":result.returncode,"stdout":result.stdout,"stderr":result.stderr})
    assert result.returncode==0,result.stdout+result.stderr
report={"epochs":epoch_records,"runs":run_records,"distinctPassingCasesByPlatform":{platform:sorted(names) for platform,names in platform_cases.items()},"verifiedAttachments":verified_attachments,"checks":checks,"reviewedFileSha256":{relative:hashlib.sha256((repository/relative).read_bytes()).hexdigest() for relative in ["PlannerNavigationUITests/SavedCategoryJourneyTests.swift","docs/prototypes/native-label-appearance.md","docs/open-decisions.md"]},"limits":"The original tablet invocation remains failed. Mac RGB-panel input, complete Mac label-file import/export, physical/signed and final whole-app acceptance are not credited."}
(packet/"validation.json").write_text(json.dumps(report,indent=2)+"\n")
(packet/"runner.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"distinctPassingCases":sum(len(names) for names in platform_cases.values()),"verifiedAttachments":verified_attachments,"sourceEpochs":len(epoch_records),"checks":[check["exitCode"] for check in checks]}))
