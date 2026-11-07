#!/usr/bin/env python3
"""Verify the pinned release assets in group_vars/all.yml.

By default the script downloads the upstream checksum for every (tool, arch)
pair and exits non-zero if a pinned hash differs. Pass --update to rewrite the
hash values in place after a deliberate version bump.

Topgrade does not publish checksum files, so its archives are downloaded and
hashed locally. Transient timeouts, HTTP 429 and 5xx responses are retried with
exponential backoff; 404 responses are reported immediately.
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.error
from dataclasses import dataclass
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - depends on the local environment
    sys.exit(
        "PyYAML is required. Install requirements-dev.txt or run this script "
        "with the same Python interpreter that runs Ansible."
    )

from http_utils import fetch_hash, fetch_text

HASH_RE = re.compile(r"\b[0-9a-f]{64}\b")


@dataclass(frozen=True)
class ChecksumFile:
    """A text file containing one or more SHA256 sums."""

    url: str
    asset: str | None = None


@dataclass(frozen=True)
class Download:
    """An archive that must be downloaded and hashed."""

    url: str


def hash_from_text(text: str, asset: str | None) -> str:
    if asset is None:
        match = HASH_RE.search(text)
        if match:
            return match.group(0)
        raise ValueError("no SHA256 in checksum file")

    for line in text.splitlines():
        parts = line.split()
        if len(parts) < 2:
            continue
        if Path(parts[-1].lstrip("*")).name == asset:
            match = HASH_RE.search(parts[0])
            if match:
                return match.group(0)
    raise ValueError(f"no SHA256 for {asset} in checksum file")


def build_specs(variables: dict) -> dict[tuple[str, str], ChecksumFile | Download]:
    kops = variables["kops_version"]
    kubectl = variables["kubectl_version"]
    helm = variables["helm_version"]
    istioctl = variables["istioctl_version"]
    kubelogin = variables["kubelogin_version"]
    kustomize = variables["kustomize_version"]
    topgrade = variables["topgrade_version"]

    specs: dict[tuple[str, str], ChecksumFile | Download] = {}
    for arch in ("amd64", "arm64"):
        specs[("kops", arch)] = ChecksumFile(
            f"https://github.com/kubernetes/kops/releases/download/v{kops}/kops-linux-{arch}.sha256"
        )
        specs[("kubectl", arch)] = ChecksumFile(
            f"https://dl.k8s.io/release/v{kubectl}/bin/linux/{arch}/kubectl.sha256"
        )
        specs[("helm", arch)] = ChecksumFile(
            f"https://get.helm.sh/helm-v{helm}-linux-{arch}.tar.gz.sha256sum"
        )
        specs[("istioctl", arch)] = ChecksumFile(
            f"https://github.com/istio/istio/releases/download/{istioctl}/"
            f"istioctl-{istioctl}-linux-{arch}.tar.gz.sha256"
        )
        specs[("kubelogin", arch)] = ChecksumFile(
            f"https://github.com/int128/kubelogin/releases/download/v{kubelogin}/"
            f"kubelogin_linux_{arch}.zip.sha256"
        )
        specs[("kustomize", arch)] = ChecksumFile(
            f"https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize/v{kustomize}/checksums.txt",
            f"kustomize_v{kustomize}_linux_{arch}.tar.gz",
        )

    for arch, asset_arch in (("x86_64", "x86_64"), ("aarch64", "aarch64")):
        specs[("topgrade", arch)] = Download(
            f"https://github.com/topgrade-rs/topgrade/releases/download/v{topgrade}/"
            f"topgrade-v{topgrade}-{asset_arch}-unknown-linux-gnu.tar.gz"
        )
    return specs


def resolve(spec: ChecksumFile | Download) -> str:
    if isinstance(spec, Download):
        return fetch_hash(spec.url)
    return hash_from_text(fetch_text(spec.url), spec.asset)


def update_file(path: Path, actual: dict[tuple[str, str], str]) -> int:
    lines = path.read_text().splitlines()
    in_section = False
    current_tool: str | None = None
    updated = 0

    for index, line in enumerate(lines):
        if re.match(r"^release_checksums:\s*$", line):
            in_section = True
            continue
        if not in_section:
            continue
        if line and not line.startswith(" "):
            break
        tool_match = re.match(r"^  ([A-Za-z0-9_]+):\s*$", line)
        if tool_match:
            current_tool = tool_match.group(1)
            continue
        arch_match = re.match(
            r"^    (amd64|arm64|x86_64|aarch64):\s*[\"']?([0-9a-f]{64})[\"']?\s*$",
            line,
        )
        if arch_match and current_tool:
            key = (current_tool, arch_match.group(1))
            if key in actual and arch_match.group(2) != actual[key]:
                lines[index] = f'    {key[1]}: "{actual[key]}"'
                updated += 1

    if not in_section:
        raise SystemExit(f"{path}: release_checksums block not found")
    path.write_text("\n".join(lines) + "\n")
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--update",
        action="store_true",
        help="rewrite the pinned hashes instead of failing on a mismatch",
    )
    parser.add_argument(
        "file",
        nargs="?",
        type=Path,
        default=Path("group_vars/all.yml"),
        help="variables file to check (default: group_vars/all.yml)",
    )
    args = parser.parse_args()

    variables = yaml.safe_load(args.file.read_text())
    specs = build_specs(variables)
    pinned = {
        (tool, arch)
        for tool, arches in variables["release_checksums"].items()
        for arch in arches
    }
    expected = set(specs)

    missing = sorted(expected - pinned)
    extra = sorted(pinned - expected)
    if missing or extra:
        for tool, arch in missing:
            print(f"ERROR {tool}/{arch}: no pinned hash", file=sys.stderr)
        for tool, arch in extra:
            print(f"ERROR {tool}/{arch}: pinned hash has no download URL", file=sys.stderr)
        return 1

    actual: dict[tuple[str, str], str] = {}
    failed = False
    mismatches = 0
    for key in sorted(specs):
        tool, arch = key
        try:
            upstream = resolve(specs[key])
        except (urllib.error.URLError, TimeoutError, ValueError) as error:
            print(f"ERROR {tool}/{arch}: {error}", file=sys.stderr)
            failed = True
            continue
        actual[key] = upstream
        current = variables["release_checksums"][tool][arch]
        if current == upstream:
            print(f"OK       {tool}/{arch}")
        else:
            mismatches += 1
            print(f"MISMATCH {tool}/{arch}: pinned={current} upstream={upstream}")

    if failed:
        return 1

    if args.update:
        updated = update_file(args.file, actual)
        print(f"Updated {updated} hash(es) in {args.file}")
        return 0

    if mismatches:
        print("Run this script with --update after verifying the new versions.", file=sys.stderr)
        return 1
    print("All pinned release checksums match upstream.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
