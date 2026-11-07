#!/usr/bin/env python3
"""Report Vagrant boxes that have a newer version than ci/ubuntu-versions.yml."""

from __future__ import annotations

import argparse
import sys
import urllib.error
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - depends on the local environment
    sys.exit(
        "PyYAML is required. Install requirements-dev.txt or run this script "
        "with the same Python interpreter that runs Ansible."
    )

from http_utils import fetch_json

DEFAULT_FILE = Path(__file__).resolve().parent / "ubuntu-versions.yml"
BOX_API = "https://app.vagrantup.com/api/v1/box/{box}"


def version_key(version: str) -> tuple[int, ...]:
    return tuple(int(part) for part in version.split("."))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--file",
        type=Path,
        default=DEFAULT_FILE,
        help="release matrix to check (default: ci/ubuntu-versions.yml)",
    )
    parser.add_argument(
        "--markdown",
        action="store_true",
        help="print the result as a Markdown table",
    )
    parser.add_argument(
        "--fail-on-updates",
        action="store_true",
        help="exit 1 when a newer box version is available",
    )
    args = parser.parse_args()

    document = yaml.safe_load(args.file.read_text())
    versions = document["versions"]

    rows: list[tuple[str, str, str, str, bool]] = []
    failed = False
    for entry in versions:
        box = entry["box"]
        pinned = entry["box_version"]
        try:
            data = fetch_json(BOX_API.format(box=box))
        except (urllib.error.URLError, TimeoutError, ValueError, KeyError) as error:
            print(f"ERROR {box}: {error}", file=sys.stderr)
            failed = True
            continue

        current = (data.get("current_version") or {}).get("version")
        if not current:
            print(f"ERROR {box}: no current_version in the API response", file=sys.stderr)
            failed = True
            continue

        newer = version_key(current) > version_key(pinned)
        rows.append((entry["release"], box, pinned, current, newer))
        if not args.markdown:
            status = "UPDATE" if newer else "OK"
            print(f"{status:6} {box}: pinned={pinned} latest={current}")

    if args.markdown:
        print("| Release | Box | Pinned | Latest | Status |")
        print("|---|---|---|---|---|")
        for release, box, pinned, current, newer in rows:
            status = "newer available" if newer else "up to date"
            print(f"| {release} | `{box}` | `{pinned}` | `{current}` | {status} |")

    if failed:
        return 2
    if args.fail_on_updates and any(row[4] for row in rows):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
