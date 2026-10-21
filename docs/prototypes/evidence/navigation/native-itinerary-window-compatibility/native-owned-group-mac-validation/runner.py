from pathlib import Path
import gzip,hashlib,json,os,subprocess
repository=Path("/Users/dinh-van.colomban/Workspace/private/planner")
assert Path.cwd().resolve()==repository
parent=repository/"docs/prototypes/evidence/navigation/native-itinerary-window-compatibility"
evidence=parent/"native-owned-group-mac-after-readiness"
packet=parent/"native-owned-group-mac-validation"
packet.mkdir(exist_ok=False)
tracked=set(subprocess.check_output(["git","ls-files","-z"],cwd=repository).decode().split("\0"))
hashes=json.loads((evidence/"source-sha256.json").read_text())
checked=0
for relative,digest in hashes.items():
    if relative not in tracked:continue
    assert hashlib.sha256((repository/relative).read_bytes()).hexdigest()==digest,relative
    checked+=1
summary=json.loads((evidence/"test-results-summary.json").read_text())
assert (summary["totalTestCount"],summary["passedTests"],summary["failedTests"],summary["skippedTests"])==(2,2,0,0)
assert json.loads((evidence/"exit.json").read_text())["exitCode"]==0
attachments=json.loads((evidence/"selected-attachments.json").read_text())["attachments"]
for attachment in attachments:
    path=evidence/attachment["retainedFileName"]
    content=path.read_bytes()
    if path.suffix==".gz":content=gzip.decompress(content)
    assert hashlib.sha256(content).hexdigest()==attachment["sha256"]
commands=[
["xcrun","swift-format","lint","--strict","PlannerNavigationUITests/SavedLabelsJourneyTests.swift"],
["pnpm","dlx","markdownlint-cli2@0.23.3","--config","docs/prototypes/evidence/navigation/native-empty-recovery-graph/markdownlint.jsonc","docs/prototypes/native-owned-association-undo.md","docs/open-decisions.md"],
["git","diff","--check"]]
results=[]
for command in commands:
    result=subprocess.run(command,cwd=repository,env=dict(os.environ,DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"),capture_output=True,text=True)
    results.append({"command":command,"exitCode":result.returncode,"stdout":result.stdout,"stderr":result.stderr})
    assert result.returncode==0,result.stdout+result.stderr
report={"repositoryHead":subprocess.check_output(["git","rev-parse","HEAD"],cwd=repository,text=True).strip(),"checkedTrackedInputs":checked,"sourceSnapshotSha256":hashlib.sha256((evidence/"source-sha256.json").read_bytes()).hexdigest(),"actualResult":{"passedTests":2,"failedTests":0,"skippedTests":0},"retainedAttachmentsVerified":len(attachments),"checks":results,"limits":"Grouped Mac restoration and saved-content relaunch. No native Mac Edit-menu history-expiry assertion, physical/signed or whole-app acceptance."}
(packet/"validation.json").write_text(json.dumps(report,indent=2)+"\n")
(packet/"runner.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"checkedTrackedInputs":checked,"passingNativeCases":2,"verifiedCaptures":len(attachments),"checkExitCodes":[row["exitCode"] for row in results]}))
