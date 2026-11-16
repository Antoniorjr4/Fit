#!/usr/bin/env bash
set -euo pipefail

# Source only. This script must run on a Mac with Xcode and XcodeGen.
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build requires macOS and the iOS SDK in Xcode. No build was started." >&2
  exit 2
fi
for tool in xcodebuild xcrun xcodegen python3; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Required tool is missing: $tool" >&2
    exit 2
  fi
done

fit_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fit_evidence="$fit_repo_root/build/ui-evidence"
fit_derived="$fit_repo_root/build/DerivedData"
mkdir -p "$fit_evidence"

{
  xcodebuild -version
  xcodegen --version
  git -C "$fit_repo_root" rev-parse HEAD || true
} > "$fit_evidence/environment.txt"

cd "$fit_repo_root/ios"
xcodegen generate --spec project.yml 2>&1 | tee "$fit_evidence/project-generation.log"

xcodebuild \
  -project FitLambda.xcodeproj \
  -scheme FitLambda \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$fit_derived" \
  CODE_SIGNING_ALLOWED=NO \
  build 2>&1 | tee "$fit_evidence/build.log"

fit_app="$fit_derived/Build/Products/Debug-iphonesimulator/FitLambda.app"
if [[ ! -d "$fit_app" ]]; then
  echo "The expected simulator app was not produced." >&2
  exit 1
fi
ditto -c -k --sequesterRsrc --keepParent "$fit_app" "$fit_evidence/FitLambda-simulator.zip"

if [[ "${CAPTURE_SCREENSHOT:-1}" != "1" ]]; then
  echo "Native simulator build completed. Screenshot not requested."
  exit 0
fi

xcrun simctl list devices available --json > "$fit_evidence/available-simulators.json"
fit_simulator_id="$(python3 - "$fit_evidence/available-simulators.json" <<'PY'
import json, re, sys
with open(sys.argv[1], encoding='utf-8') as handle:
    devices = json.load(handle).get('devices', {})
candidates = []
for runtime, entries in devices.items():
    match = re.search(r'iOS-(\d+)-(\d+)', runtime)
    if not match:
        continue
    version = tuple(map(int, match.groups()))
    if version < (17, 0):
        continue
    for device in entries:
        if device.get('isAvailable') and device.get('name', '').startswith('iPhone'):
            candidates.append((version, device.get('state') == 'Booted', device['udid']))
if not candidates:
    sys.exit('No available iPhone simulator with iOS 17 or newer. Build succeeded; capture requires an installed runtime.')
print(max(candidates)[2])
PY
)"

# boot returns an error for an already booted simulator; bootstatus below is
# authoritative and fails the script if the device cannot become ready.
xcrun simctl boot "$fit_simulator_id" 2> "$fit_evidence/simulator-boot.log" || true
xcrun simctl bootstatus "$fit_simulator_id" -b
xcrun simctl status_bar "$fit_simulator_id" override --time '9:41' --batteryState charged --batteryLevel 100
xcrun simctl ui "$fit_simulator_id" appearance dark
xcrun simctl install "$fit_simulator_id" "$fit_app"
xcrun simctl launch "$fit_simulator_id" com.annalabs.fitlambda | tee "$fit_evidence/launch.log"

# Allow the first rendered frame to settle before collecting the visual.
sleep 3
xcrun simctl io "$fit_simulator_id" screenshot "$fit_evidence/FitLambda-native-dark.png"
echo "Build, simulator launch and screenshot completed. No iPhone IPA or TestFlight release was created."
