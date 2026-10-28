#!/usr/bin/env python3
"""Give the sideload host and helper matching, separate identities in CI."""

import argparse
from pathlib import Path
import re


UPSTREAM_ID = "com.aoshuang.manicemu"


def prepare(root: Path, bundle_id: str) -> None:
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+){2,}", bundle_id):
        raise ValueError("Use a reverse-DNS bundle ID without spaces or wildcards")
    if bundle_id == UPSTREAM_ID:
        raise ValueError("Pocket 3DS must have its own bundle identifier")

    base = root / "ManicEmu/ManicEmu/Resources/Config-Base.xcconfig"
    helper = root / "ManicEmu/ManicEmu/Resources/JITEnablerExtension.xcconfig"
    project = root / "ManicEmu/ManicEmu.xcodeproj/project.pbxproj"
    edits = []
    for path, setting, value in (
        (base, "APP_BUNDLE_IDENTIFIER", bundle_id),
        (helper, "PRODUCT_BUNDLE_IDENTIFIER", bundle_id + ".JITEnabler"),
    ):
        original = path.read_text(encoding="utf-8")
        updated, count = re.subn(
            rf"(?m)^{setting}\s*=\s*[^\r\n]+$", f"{setting} = {value}", original
        )
        if count != 1:
            raise ValueError(f"Expected one {setting} setting in {path.name}; found {count}")
        edits.append((path, updated))

    original = project.read_text(encoding="utf-8")
    old = f"PRODUCT_BUNDLE_IDENTIFIER = {UPSTREAM_ID}.JITEnabler;"
    new = f"PRODUCT_BUNDLE_IDENTIFIER = {bundle_id}.JITEnabler;"
    if original.count(old) == 3:
        updated = original.replace(old, new)
    elif original.count(new) == 3 and old not in original:
        updated = original
    else:
        raise ValueError("JIT helper build configurations changed; review the Xcode project")
    edits.append((project, updated))

    # Validate every replacement before changing any file.
    for path, updated in edits:
        path.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--bundle-id", required=True)
    args = parser.parse_args()
    prepare(args.root.resolve(), args.bundle_id)
    print(f"Prepared host {args.bundle_id} and its JITEnabler extension")
