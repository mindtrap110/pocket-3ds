#!/bin/bash
# SPDX-License-Identifier: AGPL-3.0-or-later
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="$PROJECT_ROOT/build/pocket-3ds"
BUNDLE_ID="${POCKET_BUNDLE_ID:-io.github.mindtrap110.pocket3ds}"
PROJECT="$PROJECT_ROOT/ManicEmu/ManicEmu.xcodeproj"
ENTITLEMENTS="$PROJECT_ROOT/Scripts/ci/Sideload.entitlements"
mkdir -p "$OUTPUT_DIR"
exec > >(tee "$OUTPUT_DIR/packaging.log") 2>&1

if [[ "$(uname -s)" != Darwin ]]; then
    echo 'error: An iOS device build requires macOS and Xcode; use the GitHub workflow.' >&2
    exit 1
fi
for tool in xcodebuild xcrun codesign lipo ditto python3 git; do
    command -v "$tool" >/dev/null || { echo "error: Missing tool: $tool" >&2; exit 1; }
done
XCODE_VERSION="$(xcodebuild -version | head -n 1)"
XCODE_MAJOR="$(printf '%s\n' "$XCODE_VERSION" | awk '{split($2,v,"."); print v[1]}')"
if [[ "$XCODE_MAJOR" -lt 26 ]]; then
    echo 'error: Xcode 26 or newer is required.' >&2
    exit 1
fi
cd "$PROJECT_ROOT"
if git submodule status --recursive | LC_ALL=C grep -qE '^[-+U]'; then
    echo 'error: Initialize the pinned submodules with git submodule update --init --recursive.' >&2
    exit 1
fi
bash Scripts/VerifyLFS.sh
if [[ ! -s StikJIT/idevice/libidevice_ffi.a ]]; then
    echo 'error: The pinned StikJIT native library is missing.' >&2
    exit 1
fi

python3 Scripts/ci/prepare_project.py --root "$PROJECT_ROOT" --bundle-id "$BUNDLE_ID"

# Let the destination select the device SDK. A global -sdk breaks R.swift's
# mixed macOS tool / iOS runtime dependency graph (R.swift issue #805).
BUILD_OPTIONS=(
    -project "$PROJECT"
    -scheme ManicEmuSideload
    -configuration SideloadRelease
    -destination 'generic/platform=iOS'
    -derivedDataPath "$OUTPUT_DIR/DerivedData"
    -clonedSourcePackagesDirPath "$OUTPUT_DIR/SourcePackages"
    -onlyUsePackageVersionsFromResolvedFile
    -skipPackagePluginValidation
    -skipMacroValidation
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGNING_REQUIRED=NO
    CODE_SIGN_IDENTITY=
    DEVELOPMENT_TEAM=
    COMPILER_INDEX_STORE_ENABLE=NO
    ONLY_ACTIVE_ARCH=YES
)
xcodebuild "${BUILD_OPTIONS[@]}" -resolvePackageDependencies 2>&1 | tee "$OUTPUT_DIR/packages.log"
xcodebuild "${BUILD_OPTIONS[@]}" build 2>&1 | tee "$OUTPUT_DIR/xcodebuild.log"

BUILT_APP="$OUTPUT_DIR/DerivedData/Build/Products/SideloadRelease-iphoneos/ManicEmuSideload.app"
if [[ ! -d "$BUILT_APP" ]]; then
    echo 'error: Xcode did not produce ManicEmuSideload.app at the expected device-build path.' >&2
    exit 1
fi
STAGING_DIR="$(mktemp -d "$OUTPUT_DIR/package.XXXXXX")"
mkdir -p "$STAGING_DIR/Payload"
APP_PATH="$STAGING_DIR/Payload/ManicEmuSideload.app"
ditto "$BUILT_APP" "$APP_PATH"

# No device certificates or provisioning profiles belong in this artifact.
# Ad-hoc signatures preserve the intended debug entitlement for SideStore's
# later device signing. They do not authorize installation on an iPhone.
if find "$APP_PATH" -name embedded.mobileprovision -print | grep -q .; then
    echo 'error: Unexpected provisioning profile in the build; refusing to upload it.' >&2
    exit 1
fi
while IFS= read -r -d '' binary; do
    codesign --force --sign - --timestamp=none "$binary"
done < <(find "$APP_PATH" -type f -name '*.dylib' -print0)
while IFS= read -r -d '' framework; do
    codesign --force --sign - --timestamp=none "$framework"
done < <(find "$APP_PATH" -depth -type d -name '*.framework' -print0)
while IFS= read -r -d '' extension; do
    codesign --force --sign - --timestamp=none --generate-entitlement-der \
        --entitlements "$ENTITLEMENTS" "$extension"
done < <(find "$APP_PATH" -depth -type d -name '*.appex' -print0)
codesign --force --sign - --timestamp=none --generate-entitlement-der \
    --entitlements "$ENTITLEMENTS" "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
codesign -d --entitlements :- "$APP_PATH" > "$OUTPUT_DIR/host-entitlements.plist"

python3 - "$APP_PATH" "$BUNDLE_ID" "$OUTPUT_DIR" <<'PY'
import json
from pathlib import Path
import plistlib
import subprocess
import sys

app, bundle_id, output = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3])
info = plistlib.loads((app / 'Info.plist').read_bytes())
if info['CFBundleIdentifier'] != bundle_id:
    raise SystemExit('error: Unexpected host bundle ID')
helpers = list((app / 'PlugIns').glob('*.appex'))
if len(helpers) != 1:
    raise SystemExit('error: Expected exactly one JIT helper extension')
helper_info = plistlib.loads((helpers[0] / 'Info.plist').read_bytes())
if helper_info['CFBundleIdentifier'] != bundle_id + '.JITEnabler':
    raise SystemExit('error: JIT helper bundle ID must belong to the host app')
entitlements = plistlib.loads((output / 'host-entitlements.plist').read_bytes())
if entitlements.get('get-task-allow') is not True:
    raise SystemExit('error: Missing debug entitlement for later device signing')
executables = [app / info['CFBundleExecutable'], helpers[0] / helper_info['CFBundleExecutable']]
for relative in ('Frameworks/azahar.libretro.framework/azahar.libretro', 'Frameworks/Citra.framework/Citra'):
    executables.append(app / relative)
for executable in executables:
    if not executable.is_file():
        raise SystemExit(f'error: Missing app, JIT helper, or 3DS core: {executable.name}')
    subprocess.run(['lipo', str(executable), '-verify_arch', 'arm64'], check=True)
metadata = {
    'commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
    'bundle_id': bundle_id,
    'scheme': 'ManicEmuSideload',
    'configuration': 'SideloadRelease',
    'version': info.get('CFBundleShortVersionString'),
    'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
    'signing': 'ad-hoc; requires SideStore device signing',
    'device_tested': False,
}
(output / 'build-info.json').write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
PY

COPYFILE_DISABLE=1 ditto -c -k --keepParent "$STAGING_DIR/Payload" "$OUTPUT_DIR/Pocket3DS.ipa"
(cd "$OUTPUT_DIR" && shasum -a 256 Pocket3DS.ipa > Pocket3DS.ipa.sha256)
echo "Created $OUTPUT_DIR/Pocket3DS.ipa; sign and install it with SideStore."
if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' '### IPA generated' \
        'Download the pocket-3ds-ipa artifact, extract it in Files, and open Pocket3DS.ipa in SideStore.' \
        'The artifact expires after one day. This build has not been tested on an iPhone.' \
        >> "$GITHUB_STEP_SUMMARY"
fi
