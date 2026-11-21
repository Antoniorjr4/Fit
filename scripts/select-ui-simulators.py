"""Select reproducible full-size and compact iPhones matching the active SDK."""
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as source:
    runtimes = json.load(source)["devices"]
sdk = tuple(int(part) for part in sys.argv[2].split(".")[:2])
candidates = []
for runtime, devices in runtimes.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match or tuple(map(int, match.groups())) != sdk:
        continue
    candidates.extend(dict(device, runtime=runtime) for device in devices
                      if device.get("isAvailable") and device["name"].startswith("iPhone"))
if not candidates:
    sys.exit(f"No available iPhone runtime matches the active simulator SDK {sys.argv[2]}.")

main = next((d for d in candidates if d["name"] == "iPhone 16 Pro Max"), None)
main = main or next((d for d in candidates if "Pro Max" in d["name"]), candidates[0])
compact = next((d for d in candidates if d["name"] == "iPhone SE (3rd generation)"), None)
if compact is None:
    sys.exit("A compact iPhone SE (3rd generation) simulator is required for the UI check.")
json.dump({"sdk": sys.argv[2], "main": main, "compact": compact}, sys.stdout, indent=2)
print()
