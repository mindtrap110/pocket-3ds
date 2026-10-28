# Pocket 3DS

This is a personal fork of Manic EMU for an iPhone 15. The owner mostly works
from a phone. Keep the edit -> cloud build -> SideStore install loop usable.

## Current scope

- First establish a reproducible `ManicEmuSideload` device build. Keep the
  upstream emulator cores, JIT protocol, UI, save formats, and licenses intact.
- The first IPA retains the upstream UI and display name. Its separate bundle
  identifier prevents it from overwriting the original app.
- A successful Xcode build or an enabled-JIT indicator does not prove a game
  runs correctly or that its CPU JIT is actually executing. Report those checks
  separately. Real-device checks belong to the owner.
- Do not assume the phone's iOS version from an older conversation. JIT changes
  require the current version and device logs.

## Build and validation

- Use `bash Scripts/BuildSideloadIPA.sh` on macOS with Xcode 26 or newer.
- The scheme is `ManicEmuSideload`, configuration `SideloadRelease`, and
  destination `generic/platform=iOS`. Simulator builds cannot validate this IPA.
- Initialize the pinned submodules and hydrate Git LFS before building.
- On Linux, run `python3 -m unittest discover -s Scripts/ci -p 'test_*.py'`
  and `bash -n Scripts/BuildSideloadIPA.sh`. Do not claim an iOS build passed.
- `Scripts/ci/prepare_project.py` only changes the build checkout's bundle IDs.
  Do not commit those generated changes or generated app bundles.
- Keep build diagnostics on failure. Publish an IPA artifact only on success.

## Data and distribution

- Never delete an installed app or its saves as a debugging step. Preserve
  backup/export and stable identifiers across subsequent Pocket 3DS updates.
- CI produces an ad-hoc-signed transport IPA. SideStore must sign it for the
  owner's device; preserve `get-task-allow` and the JIT helper extension.
- Do not add Apple credentials, pairing files, provisioning profiles, ROMs,
  system keys, or service credentials to changes, logs, or build artifacts.
- Keep upstream attribution and licenses. Use a branch for development and
  describe changed behavior, validation, and remaining device checks in Korean.
