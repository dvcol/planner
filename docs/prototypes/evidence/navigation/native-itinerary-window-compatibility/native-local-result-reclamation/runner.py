from pathlib import Path
import gzip,hashlib,json,shutil,subprocess
repository=Path("/Users/dinh-van.colomban/Workspace/private/planner")
parent=repository/"docs/prototypes/evidence/navigation/native-itinerary-window-compatibility"
phases=["native-plan-opening-mac-ui-after-readiness","native-plan-opening-mac-ui-confirmation","native-plan-opening-mac-draft-diagnostic","native-plan-opening-mac-draft-compatibility","native-plan-opening-mac-filled-window"]
records=[]
for phase in phases:
    packet=parent/phase
    command=json.loads((packet/"command.json").read_text())
    outcome=json.loads((packet/"exit.json").read_text())
    assert outcome["exitCode"] in [0,65] and not outcome.get("runnerTimedOut",False)
    tracked=subprocess.run(["git","ls-files","--error-unmatch",str((packet/"test-results-summary.json").relative_to(repository))],cwd=repository,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
    assert tracked.returncode==0
    assert (packet/"test.log.gz").is_file()
    manifest=packet/"original-attachment-manifest.json.gz"
    gzip.decompress(manifest.read_bytes())
    attachments=json.loads((packet/"selected-attachments.json").read_text())["attachments"]
    for attachment in attachments:
        name=attachment["retainedFileName"]
        assert Path(name).name==name
        retained=packet/name
        assert retained.is_file() and not retained.is_symlink()
        content=retained.read_bytes()
        if name.endswith(".gz"): content=gzip.decompress(content)
        assert hashlib.sha256(content).hexdigest()==attachment["sha256"],name
    bundle=Path(command[command.index("-resultBundlePath")+1])
    assert bundle.is_dir() and not bundle.is_symlink()
    canonical=bundle.resolve(strict=True)
    assert canonical.parent==Path("/private/tmp") and canonical.name=="PlannerItemWindow-"+phase+".xcresult"
    records.append({"phase":phase,"bundle":str(canonical),"retainedAttachments":len(attachments),"retainedSummarySha256":hashlib.sha256((packet/"test-results-summary.json").read_bytes()).hexdigest(),"allocatedKibibytes":int(subprocess.check_output(["du","-sk",str(canonical)],text=True).split()[0])})
for record in records:
    shutil.rmtree(record["bundle"])
    print("Removed completed temporary result:",record["phase"],flush=True)
report={"scope":"Five completed agent-owned temporary result bundles; committed summaries/logs and hash-verified exported captures retained.","removed":records,"freeBytesAfter":shutil.disk_usage("/private/tmp").free}
packet=parent/"native-local-result-reclamation"
packet.mkdir(exist_ok=False)
(packet/"reclamation.json").write_text(json.dumps(report,indent=2)+"\n")
print(json.dumps({"removedBundles":len(records),"allocatedMebibytes":sum(record["allocatedKibibytes"] for record in records)/1024,"freeMebibytes":report["freeBytesAfter"]/1024/1024}))
