from pathlib import Path
from datetime import datetime,timezone
import gzip,hashlib,json,shutil,subprocess
repository=Path("/Users/dinh-van.colomban/Workspace/private/planner")
assert Path.cwd().resolve()==repository
records=json.loads(Path("/private/tmp/PlannerCompletedResultExtraCandidates.json").read_text())
tree=subprocess.check_output(["git","ls-tree","-r","-z","HEAD","docs/prototypes/evidence"])
committed={}
for entry in tree.split(b"\0"):
    if not entry:continue
    metadata,relative=entry.split(b"\t",1)
    committed[relative.decode()]=metadata.split()[2].decode()
def verify_committed(path):
    assert path.is_file() and not path.is_symlink(),str(path)
    relative=str(path.relative_to(repository))
    content=path.read_bytes()
    digest=hashlib.sha1(b"blob "+str(len(content)).encode()+b"\0"+content).hexdigest()
    assert committed.get(relative)==digest,relative
    return content
verified=[]
summaries={}
for record in records:
    packet=repository/record["packet"]
    command=json.loads(verify_committed(packet/"command.json"))
    outcome=json.loads(verify_committed(packet/"exit.json"))
    assert outcome["exitCode"]==record["exitCode"] and not outcome.get("runnerTimedOut",False)
    verify_committed(packet/"test.log.gz")
    manifest=json.loads(verify_committed(packet/record["manifest"]))
    attachments=manifest["attachments"] if isinstance(manifest,dict) else manifest
    for attachment in attachments:
        name=attachment.get("retainedFileName",attachment.get("exportedFileName"))
        assert name and Path(name).name==name
        path=packet/name
        if not path.is_file():path=packet/(name+".gz")
        content=verify_committed(path)
        if attachment.get("sha256"):
            if path.suffix==".gz":content=gzip.decompress(content)
            assert hashlib.sha256(content).hexdigest()==attachment["sha256"],str(path)
    raw=Path(record["bundle"])
    assert raw.is_dir() and not raw.is_symlink() and raw.resolve(strict=True)==raw
    assert raw.parent==Path("/private/tmp") and raw.name.startswith("Planner") and raw.suffix==".xcresult"
    assert Path(command[command.index("-resultBundlePath")+1]).resolve(strict=True)==raw
    summary_process=subprocess.run(["xcrun","xcresulttool","get","test-results","summary","--path",str(raw)],capture_output=True,text=True,env=dict(__import__("os").environ,DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"),timeout=60)
    assert summary_process.returncode==0,summary_process.stderr
    summary=json.loads(summary_process.stdout)
    summary_name=raw.name+".summary.json"
    summaries[summary_name]=summary_process.stdout
    record=dict(record,summaryFile=summary_name,summaryCounts={key:summary.get(key) for key in ["totalTestCount","passedTests","failedTests","skippedTests"]})
    verified.append(dict(record,retainedAttachments=len(attachments),verification="Every selected attachment, log, command and outcome matches the committed Git blob. The actual raw result summary is exported before removal."))
assert verified
audit=repository/"docs/prototypes/evidence/navigation/native-itinerary-window-compatibility/native-completed-result-cleanup-extended"
audit.mkdir(exist_ok=False)
for name,content in summaries.items():(audit/name).write_text(content)
(audit/"verified-before-removal.json").write_text(json.dumps(verified,indent=2)+"\n")
open_files=subprocess.run(["lsof","-nP","-Fn"],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True,timeout=60)
assert open_files.returncode in [0,1]
for record in verified:
    prefix="n"+record["bundle"]+"/"
    assert not any(line.startswith(prefix) or line=="n"+record["bundle"] for line in open_files.stdout.splitlines()),record["bundle"]
before=shutil.disk_usage("/private/tmp").free
for record in verified:
    shutil.rmtree(record["bundle"])
    assert not Path(record["bundle"]).exists()
report={"completedAt":datetime.now(timezone.utc).isoformat(),"scope":"Completed Planner temporary raw result bundles only. Current compiler products, active results, source and retained committed evidence are unchanged.","removed":verified,"nominalAllocatedBytes":sum(record["allocatedBytes"] for record in verified),"freeBytesBefore":before,"freeBytesAfter":shutil.disk_usage("/private/tmp").free,"freeSpaceNote":"APFS free space also reflects concurrent work and shared or cloned allocation."}
packet=audit
(packet/"reclamation.json").write_text(json.dumps(report,indent=2)+"\n")
(packet/"runner.py").write_bytes(Path(__file__).read_bytes())
print(json.dumps({"removedBundles":len(verified),"nominalGibibytes":report["nominalAllocatedBytes"]/1024**3,"freeGibibytesAfter":report["freeBytesAfter"]/1024**3}))
