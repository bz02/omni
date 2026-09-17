#!/usr/bin/env python3
"""Extract named XCTest screenshot attachments from an .xcresult bundle.

App Store screenshots must show the real app, so these come from the journey
tests rather than from mockups. Apple rejects sizes it does not recognise, so
every extracted image is checked against the accepted pixel dimensions for the
requested device class and the run fails loudly with what it actually got.
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import shutil
import struct
import subprocess
import sys
from pathlib import Path

# Portrait and landscape pixel sizes App Store Connect accepts, per class.
# Checked against Apple's "Screenshot specifications" table; re-verify when
# Apple adds a display size, because an unlisted size is silently rejected.
ACCEPTED = {
    "iphone-6.9": {(1320, 2868), (2868, 1320), (1290, 2796), (2796, 1290)},
    "iphone-6.5": {(1242, 2688), (2688, 1242), (1284, 2778), (2778, 1284)},
    "ipad-13": {(2064, 2752), (2752, 2064), (2048, 2732), (2732, 2048)},
}


def png_size(path: Path) -> tuple[int, int]:
    """Read width/height from the IHDR chunk without a third-party decoder."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"{path.name} is not a PNG")
    return struct.unpack(">II", header[16:24])


def export_modern(xcresult: Path, out_dir: Path) -> bool:
    """Xcode 16+ exports attachments directly, with a manifest naming each one."""
    probe = subprocess.run(
        ["xcrun", "xcresulttool", "export", "attachments",
         "--path", str(xcresult), "--output-path", str(out_dir)],
        capture_output=True, text=True,
    )
    if probe.returncode != 0:
        print(f"  modern export unavailable: {probe.stderr.strip().splitlines()[:1]}")
        return False
    manifest = out_dir / "manifest.json"
    if not manifest.exists():
        print("  modern export produced no manifest.json")
        return False
    entries = json.loads(manifest.read_text())
    renamed = 0
    for test in entries:
        for attachment in test.get("attachments", []):
            exported = attachment.get("exportedFileName")
            # suggestedHumanReadableName carries the name the test assigned.
            label = attachment.get("suggestedHumanReadableName") or exported
            if not exported or not label:
                continue
            source = out_dir / exported
            if not source.exists() or not label.lower().endswith(".png"):
                label = f"{Path(label).stem}.png"
            if not source.exists():
                continue
            target = out_dir / re.sub(r"[^A-Za-z0-9._-]", "-", label)
            if source != target:
                source.replace(target)
            renamed += 1
    return renamed > 0


def export_legacy(xcresult: Path, out_dir: Path) -> bool:
    """Older toolchains need the result graph walked by hand."""
    def get(object_id: str | None) -> dict:
        command = ["xcrun", "xcresulttool", "get", "--format", "json",
                   "--path", str(xcresult), "--legacy"]
        if object_id:
            command += ["--id", object_id]
        result = subprocess.run(command, capture_output=True, text=True)
        if result.returncode != 0:
            raise RuntimeError(result.stderr.strip())
        return json.loads(result.stdout)

    def values(node: dict, key: str) -> list:
        return node.get(key, {}).get("_values", [])

    def scalar(node: dict, key: str) -> str | None:
        return node.get(key, {}).get("_value")

    found = 0

    def walk(summary_id: str) -> None:
        nonlocal found
        for activity in _iter_activities(get(summary_id)):
            for attachment in values(activity, "attachments"):
                name = scalar(attachment, "name")
                payload = scalar(attachment, "payloadRef") or (
                    attachment.get("payloadRef", {}).get("id", {}).get("_value"))
                if not name or not payload:
                    continue
                target = out_dir / re.sub(r"[^A-Za-z0-9._-]", "-", f"{Path(name).stem}.png")
                blob = subprocess.run(
                    ["xcrun", "xcresulttool", "get", "--path", str(xcresult),
                     "--id", payload, "--legacy"],
                    capture_output=True,
                )
                if blob.returncode == 0 and blob.stdout[:8] == b"\x89PNG\r\n\x1a\n":
                    target.write_bytes(blob.stdout)
                    found += 1

    def _iter_activities(node: dict):
        for activity in values(node, "activitySummaries"):
            yield activity
            yield from _iter_activities(activity)

    root = get(None)
    for action in values(root, "actions"):
        tests_ref = action.get("actionResult", {}).get("testsRef", {})
        tests_id = tests_ref.get("id", {}).get("_value")
        if not tests_id:
            continue
        for bundle in values(get(tests_id), "summaries"):
            for testable in values(bundle, "testableSummaries"):
                stack = list(values(testable, "tests"))
                while stack:
                    node = stack.pop()
                    stack.extend(values(node, "subtests"))
                    summary_id = node.get("summaryRef", {}).get("id", {}).get("_value")
                    if summary_id:
                        walk(summary_id)
    return found > 0


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--xcresult", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--device-class", required=True, choices=sorted(ACCEPTED))
    args = parser.parse_args()

    if args.output.exists():
        shutil.rmtree(args.output)
    args.output.mkdir(parents=True)

    if not export_modern(args.xcresult, args.output) and not export_legacy(
            args.xcresult, args.output):
        print("No screenshot attachments were extracted.", file=sys.stderr)
        return 1

    # Drop non-image exports the manifest may have carried along.
    images = []
    for path in sorted(args.output.iterdir()):
        if path.name == "manifest.json":
            path.unlink()
            continue
        if not path.is_file():
            continue
        try:
            images.append((path, png_size(path)))
        except ValueError:
            path.unlink()

    if not images:
        print("Attachments were exported but none were PNG screenshots.", file=sys.stderr)
        return 1

    accepted = ACCEPTED[args.device_class]
    wrong = [(p.name, size) for p, size in images if size not in accepted]
    for path, size in images:
        print(f"  {path.name}: {size[0]}x{size[1]}")
    if wrong:
        print(f"\n{len(wrong)} screenshot(s) are not an App Store size for "
              f"{args.device_class}.", file=sys.stderr)
        print(f"Accepted: {sorted(accepted)}", file=sys.stderr)
        for name, size in wrong:
            print(f"  {name} is {size[0]}x{size[1]}", file=sys.stderr)
        print("Pick a simulator whose native resolution is an accepted size; "
              "do not rescale, Apple rejects resampled screenshots.", file=sys.stderr)
        return 1

    print(f"\n{len(images)} screenshot(s) at an accepted {args.device_class} size.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
