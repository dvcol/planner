from pathlib import Path
import hashlib,json,sys,uuid
platform = sys.argv[1]
devices = {'phone':'2A49C66C-C8A4-435F-B98A-9A90706780DE','tablet':'FBD72DAB-1D40-4E64-912D-7F9763E00446'}
text_directory = Path(f'/private/tmp/PlannerUnavailableExport{platform.title()}Text')
expectations = [path for path in text_directory.glob('*.txt') if 'Fixture: ' in path.read_text() and 'Generation: 2' in path.read_text()]
assert len(expectations) == 1, expectations
expected = dict(line.split(': ',1) for line in expectations[0].read_text().splitlines())
assert str(uuid.UUID(expected['Fixture'])).upper() == expected['Fixture']
item_identifier = expected['Item'].removeprefix('saved.recovery.source.item.')
tag_identifier = expected['Tag'].removeprefix('saved.recovery.source.tag.')
assert str(uuid.UUID(item_identifier)).upper() == item_identifier
assert str(uuid.UUID(tag_identifier)).upper() == tag_identifier
provider_root = Path('/Users/dinh-van.colomban/Library/Developer/CoreSimulator/Devices') / devices[platform] / 'data/Containers/Shared/AppGroup'
delivered = [directory / expected['Filename'] for directory in provider_root.glob('*/File Provider Storage') if (directory / expected['Filename']).is_file()]
assert len(delivered) == 1, delivered
content = delivered[0].read_bytes()
backup = json.loads(content)
permitted_root = {'format','formatVersion','sources','memberships','itineraryEntries','schedules','labelAssociations','ownedLinks','completionChanges','expandedCompletions','contextAliases','restorationFamilies','deletionMarkers'}
assert set(backup) == permitted_root
assert backup['format'] == 'planner-data' and backup['formatVersion'] == 2
assert len(backup['sources']) == 2
sources = {source['kind']:source for source in backup['sources']}
assert set(sources) == {'item','tag'}
item,tag = sources['item'],sources['tag']
assert item['id'] == item_identifier and tag['id'] == tag_identifier
assert item['content']['title'] == 'Unavailable museum'
assert item['content']['notes'] == 'Saved before the store became unavailable'
assert item['globalDone'] is False and item['archived'] is False
assert tag['content']['name'] == 'Retained travel'
assert len(backup['labelAssociations']) == 1
association = backup['labelAssociations'][0]
assert association['owner'] == {'kind':'item','id':item_identifier,'lifetimeId':item['lifetimeId']}
assert association['label'] == {'kind':'tag','id':tag_identifier,'lifetimeId':tag['lifetimeId']}
for group in permitted_root - {'format','formatVersion','sources','labelAssociations'}:
    assert backup[group] == [], group
output = Path('/Users/dinh-van.colomban/Workspace/private/planner/docs/prototypes/evidence/navigation/native-unavailable-store-export')
output.mkdir(exist_ok=True)
(output / f'{platform}-output.json').write_bytes(content)
record = {'expectation':str(expectations[0]),'values':expected,'deliveredPaths':[str(path) for path in delivered],'sha256':hashlib.sha256(content).hexdigest(),'bytes':len(content),'checks':'Exact permitted public root, portable format 2, two native-observed source identities, expected Item title/notes/Todo/Active and Tag name, one correctly lifetime-bound association, every other data group empty. No selected-byte comparison or full-graph claim.'}
(output / f'{platform}-output-provenance.json').write_text(json.dumps(record,indent=2)+'\n')
assert (output / f'{platform}-output.json').read_bytes() == content
print(json.dumps({'platform':platform,'bytes':len(content),'sources':len(backup['sources']),'associations':len(backup['labelAssociations']),'sha256':record['sha256']}))
