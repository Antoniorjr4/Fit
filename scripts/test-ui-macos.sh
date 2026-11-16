#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "UI journeys require macOS, Xcode and iPhone simulators." >&2
  exit 2
fi
fit_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fit_evidence="$fit_repo_root/build/ui-evidence"
fit_selection="$fit_evidence/selected-simulators.json"
if [[ ! -f "$fit_selection" ]]; then
  echo "Run build-ui-macos.sh first to select and record the simulators." >&2
  exit 2
fi
cd "$fit_repo_root/ios"

run_journeys() {
  local fit_device_key="$1"
  shift
  local fit_device_id fit_result fit_status
  fit_device_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))[sys.argv[2]]["udid"])' "$fit_selection" "$fit_device_key")"
  fit_result="$fit_evidence/$fit_device_key.xcresult"
  xcrun simctl boot "$fit_device_id" 2> "$fit_evidence/$fit_device_key-boot.log" || true
  xcrun simctl bootstatus "$fit_device_id" -b
  xcrun simctl status_bar "$fit_device_id" override --time '9:41' --batteryState charged --batteryLevel 100

  if xcodebuild \
    -project FitLambda.xcodeproj -scheme FitLambda -configuration Debug \
    -destination "platform=iOS Simulator,id=$fit_device_id" \
    -derivedDataPath "$fit_repo_root/build/DerivedData" \
    -resultBundlePath "$fit_result" \
    -parallel-testing-enabled NO \
    -test-timeouts-enabled YES -maximum-test-execution-time-allowance 240 \
    CODE_SIGNING_ALLOWED=NO "$@" test 2>&1 | tee "$fit_evidence/$fit_device_key-tests.log"; then
    fit_status=0
  else
    fit_status=$?
  fi

  if [[ -d "$fit_result" ]]; then
    xcrun xcresulttool export attachments --path "$fit_result" \
      --output-path "$fit_evidence/$fit_device_key-screenshots"
    xcrun xcresulttool get test-results summary --path "$fit_result" \
      > "$fit_evidence/$fit_device_key-summary.json"
  fi
  xcrun simctl shutdown "$fit_device_id" || true
  return "$fit_status"
}

run_journeys main
run_journeys compact \
  -only-testing:FitLambdaUITests/InterfaceJourneyTests/testGoalSaveAndCancel \
  -only-testing:FitLambdaUITests/InterfaceJourneyTests/testLargeTextNavigationAndEditing \
  -only-testing:FitLambdaUITests/InterfaceJourneyTests/testFirstLaunchLanguagePersistsAndCancelKeepsChoice \
  -only-testing:FitLambdaUITests/InterfaceJourneyTests/testGermanLargeTextAndLanguageSettings

echo "Native UI journeys passed on both recorded simulators. No physical Fit3 was used."
