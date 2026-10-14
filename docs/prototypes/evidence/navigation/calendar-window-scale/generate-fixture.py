"""Reproduce the exact benchmark input from public Planner export templates."""

import copy
import hashlib
import json
import sys
from pathlib import Path


def identifier(number):
    return f"00000000-0000-4000-8000-{number:012d}"


directory = Path(__file__).resolve().parent
backup = json.loads((directory / "seed-empty.json").read_bytes())
template = json.loads((directory / "seed-template.json").read_bytes())
list_template = next(source for source in template["sources"] if source["kind"] == "list")
item_template = next(source for source in template["sources"] if source["kind"] == "item")

for index in range(200):
    source = copy.deepcopy(list_template)
    source["id"] = source["lifetimeId"] = identifier(20000 + index)
    source["content"]["name"] = f"Travel list {index + 1}"
    backup["sources"].append(source)

for index in range(5000):
    source = copy.deepcopy(item_template)
    source["id"] = source["lifetimeId"] = identifier(10000 + index)
    source["content"]["title"] = f"Travel stop {index + 1}"
    backup["sources"].append(source)
    membership = copy.deepcopy(template["memberships"][0])
    membership["id"] = membership["lifetimeId"] = identifier(30000 + index)
    membership["item"]["id"] = membership["item"]["lifetimeId"] = source["id"]
    membership["list"]["id"] = membership["list"]["lifetimeId"] = identifier(20000 + index % 200)
    membership["rank"] = str(index // 200)
    backup["memberships"].append(membership)
    schedule = copy.deepcopy(template["schedules"][0])
    schedule["id"] = schedule["lifetimeId"] = identifier(40000 + index)
    schedule["source"]["id"] = schedule["source"]["lifetimeId"] = source["id"]
    schedule["form"]["start"] += index * 86400
    backup["schedules"].append(schedule)

encoded = json.dumps(backup, separators=(",", ":"), sort_keys=True).encode()
assert hashlib.sha256(encoded).hexdigest() == (
    "ceece309121ad136cf6cff6a8369c35c97e70e57ea94d7ba54586d68a4c4bb65"
)
Path(sys.argv[1]).write_bytes(encoded)
