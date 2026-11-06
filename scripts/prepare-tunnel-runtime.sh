#!/bin/bash
set -euo pipefail

# Run before a Mac build; Xcode only copies and signs the verified offline artifact.
plannerRoot="$(cd "$(dirname "$0")/.." && pwd)"
runtimeDirectory="$plannerRoot/.build/tunnel-runtime"
releaseURL="https://github.com/openai/tunnel-client/releases/download/v0.0.19"
mkdir -p "$runtimeDirectory"
downloadDirectory="$(mktemp -d "${TMPDIR:-/tmp}/planner-tunnel-download.XXXXXX")"
trap 'rm -rf "$downloadDirectory"' EXIT

download() {
  local filename="$1" checksum="$2"
  curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
    "$releaseURL/$filename" -o "$downloadDirectory/$filename"
  (cd "$downloadDirectory" && printf '%s  %s\n' "$checksum" "$filename" | shasum -a 256 -c -)
}

download tunnel-client-runtime-v0.0.19-darwin-arm64.zip 225760584563a1ad6ee72585bc001bae34a7141d73246a117ceed284090590cc
download tunnel-client-runtime-v0.0.19-darwin-amd64.zip e19e52f92e34f7502db87e54e6a1f5429e1828ca1cb5a821b05dc563e56fe2f4
download tunnel-client-runtime-v0.0.19-darwin-arm64-licenses.txt a22f29ac6d7be5305a38ba0b362745e65d337bc893308ffae6468ce274e192ed
download tunnel-client-runtime-v0.0.19-darwin-amd64-licenses.txt 208c70bc7b1ab826b7255e2303fb9062fb08cec9a4c549c2eead1afdbbd7a5db
for architecture in arm64 amd64; do
  ditto -x -k "$downloadDirectory/tunnel-client-runtime-v0.0.19-darwin-$architecture.zip" \
    "$downloadDirectory/$architecture"
done
lipo -create "$downloadDirectory/arm64/tunnel-client-runtime" \
  "$downloadDirectory/amd64/tunnel-client-runtime" -output "$runtimeDirectory/tunnel-client-runtime"
chmod 755 "$runtimeDirectory/tunnel-client-runtime"
codesign --force --sign - --identifier dvcol.planner.TunnelRuntime \
  --entitlements "$plannerRoot/Configuration/PlannerTunnelRuntime.entitlements" \
  "$runtimeDirectory/tunnel-client-runtime"
mkdir -p "$runtimeDirectory/TunnelRuntimeLicenses"
cp "$downloadDirectory/arm64/LICENSE" "$downloadDirectory/arm64/NOTICE" \
  "$downloadDirectory/"*-licenses.txt "$runtimeDirectory/TunnelRuntimeLicenses/"
codesign --verify --strict "$runtimeDirectory/tunnel-client-runtime"
runtimeArchitectures="$(lipo -archs "$runtimeDirectory/tunnel-client-runtime")"
[[ "$runtimeArchitectures" == 'x86_64 arm64' || "$runtimeArchitectures" == 'arm64 x86_64' ]]
plannerSDK="$(xcrun --sdk macosx --show-sdk-path)"
for architecture in arm64 x86_64; do
  xcrun swiftc -O -swift-version 6 -strict-concurrency=complete -parse-as-library \
    -sdk "$plannerSDK" -target "$architecture-apple-macosx27.0" \
    "$plannerRoot/PlannerTunnelBridge/PlannerTunnelBridge.swift" \
    -o "$downloadDirectory/PlannerTunnelBridge-$architecture"
done
lipo -create "$downloadDirectory/PlannerTunnelBridge-arm64" \
  "$downloadDirectory/PlannerTunnelBridge-x86_64" -output "$runtimeDirectory/PlannerTunnelBridge"
codesign --force --sign - --identifier dvcol.planner.TunnelBridge \
  --entitlements "$plannerRoot/Configuration/PlannerTunnelRuntime.entitlements" \
  "$runtimeDirectory/PlannerTunnelBridge"
shasum -a 256 "$plannerRoot/PlannerTunnelBridge/PlannerTunnelBridge.swift" \
  | cut -d ' ' -f 1 > "$runtimeDirectory/PlannerTunnelBridge.source.sha256"
codesign --verify --strict "$runtimeDirectory/PlannerTunnelBridge"
echo 'Prepared official tunnel-client-runtime v0.0.19 for the signed Mac build.'
