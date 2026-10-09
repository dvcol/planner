#!/usr/bin/env bash
set -euo pipefail

prototypeRoot="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
prototypePlatform="${1:-phone}"
prototypeBuildDirectory="${TMPDIR:-/tmp}/PlannerNavigationLaunch-${prototypePlatform}"
prototypePackageDirectory="${TMPDIR:-/tmp}/PlannerNavigationSourcePackages"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

case "$prototypePlatform" in
  phone)
    prototypeSimulatorName='iPhone 18 Pro'
    prototypeDestination="platform=iOS Simulator,name=${prototypeSimulatorName}"
    ;;
  tablet)
    prototypeSimulatorName='iPad Air 11-inch (M4)'
    prototypeDestination="platform=iOS Simulator,name=${prototypeSimulatorName}"
    ;;
  mac)
    prototypeDestination='platform=macOS,arch=arm64'
    ;;
  *)
    printf 'Usage: %s [phone|tablet|mac]\n' "$0" >&2
    exit 2
    ;;
esac

xcodebuild -project "$prototypeRoot/Planner.xcodeproj" -scheme PlannerNavigation \
  -destination "$prototypeDestination" -derivedDataPath "$prototypeBuildDirectory" \
  -onlyUsePackageVersionsFromResolvedFile \
  -clonedSourcePackagesDirPath "$prototypePackageDirectory" build

if [[ "$prototypePlatform" == mac ]]; then
  open -n "$prototypeBuildDirectory/Build/Products/Debug/Planner.app" --args --navigation-prototype
  exit
fi

xcrun simctl bootstatus "$prototypeSimulatorName" -b
xcrun simctl install "$prototypeSimulatorName" \
  "$prototypeBuildDirectory/Build/Products/Debug-iphonesimulator/Planner.app"
xcrun simctl launch "$prototypeSimulatorName" org.example.PlannerMCPPrototype --navigation-prototype
prototypeSimulatorApplication="$DEVELOPER_DIR/Applications/Simulator.app"
if [[ -d "$prototypeSimulatorApplication" ]]; then
  open "$prototypeSimulatorApplication"
else
  printf '%s\n' 'Planner is running in the simulator runtime. The selected Xcode bundle has no Simulator UI application.'
fi
