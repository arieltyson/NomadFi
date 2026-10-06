#!/usr/bin/env python3
"""Scan Git's index locally; never print matching content or secret values."""

import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
MAX_FILE_BYTES = 25 * 1024 * 1024
CARD = re.compile(r"(?<![\w/-])(?:[0-9][ -]?){12,18}[0-9](?![\w/-])")
LABELED_IDENTIFIER = re.compile(
    r"(?i)\b(?:account[_ -]?number|routing[_ -]?number|transit[_ -]?number|"
    r"social[_ -]?(?:security|insurance)[_ -]?number|ssn|sin)"
    r"[\s\"']{0,3}[:=][\s\"']{0,3}([0-9][0-9 -]{3,23}[0-9])\b"
)


class ScanError(Exception):
    pass


def git(*args, data=None):
    result = subprocess.run(["git", *args], input=data, capture_output=True)
    if result.returncode:
        raise ScanError("Could not read the Git index; commit blocked.")
    return result.stdout


def dependencies():
    if not shutil.which("gitleaks"):
        raise ScanError("Gitleaks is required. Install it with `brew install gitleaks`.")
    result = subprocess.run(["gitleaks", "version"], capture_output=True, text=True)
    version = re.search(r"\b(\d+)\.(\d+)\.(\d+)\b", result.stdout)
    if result.returncode or not version or tuple(map(int, version.groups())) < (8, 30, 0):
        raise ScanError("Gitleaks 8.30.0 or newer is required; update it before committing.")


def private_path(name):
    path = PurePosixPath(name)
    parts = [part.lower() for part in path.parts]
    basename = parts[-1]
    if basename.endswith(".env") or ".env." in basename:
        return basename != ".env.example"
    if any(part in {"secrets", "plaidvalidationevidence", ".aws", ".ssh"} for part in parts):
        return True
    if name.lower() in {"docs/ariel.md", "docs/financekit-application.md"}:
        return True
    if basename in {".state.json", "id_rsa", "id_ed25519", "id_ecdsa", ".npmrc", ".netrc"}:
        return True
    if path.suffix.lower() in {".key", ".pem", ".p12", ".pfx", ".log", ".db", ".sqlite", ".sqlite3", ".store"}:
        return True
    if re.search(r"\.(?:db|sqlite3?|store)-(?:wal|shm)$", basename):
        return True
    return path.suffix.lower() == ".xcconfig" and "SharedSettings" not in path.parts


def luhn(value):
    digits = [int(char) for char in value if char.isdigit()]
    if not 13 <= len(digits) <= 19 or len(set(digits)) == 1:
        return False
    total = 0
    for index, digit in enumerate(reversed(digits)):
        doubled = digit * 2 if index % 2 else digit
        total += doubled - 9 if doubled > 9 else doubled
    return total % 10 == 0


def financial_findings(data):
    if b"\0" in data:
        return []
    text = data.decode("utf-8", errors="replace")
    findings = set()
    for number, line in enumerate(text.splitlines(), 1):
        if any(luhn(match.group()) for match in CARD.finditer(line)):
            findings.add((number, "possible-payment-card"))
        if LABELED_IDENTIFIER.search(line):
            findings.add((number, "financial-or-government-identifier"))
    return sorted(findings)


def staged_entries():
    names = git("diff", "--cached", "--name-only", "--diff-filter=ACMRT", "--no-renames", "-z").split(b"\0")
    entries = {}
    for row in git("ls-files", "--stage", "-z").split(b"\0"):
        if not row:
            continue
        metadata, name = row.split(b"\t", 1)
        mode, oid, stage = metadata.split()
        if stage != b"0":
            raise ScanError("Resolve merge conflicts before committing.")
        entries[name] = (mode.decode(), oid.decode())
    return [(os.fsdecode(name), *entries[name]) for name in names if name]


def gitleaks_findings(snapshot, temp, names):
    ignore = temp / "empty.ignore"
    ignore.write_text("")
    command = [
        "gitleaks", "dir", str(snapshot), "--config", str(ROOT / ".gitleaks.toml"),
        "--no-banner", "--no-color", "--redact=100", "--log-level=error",
        "--ignore-gitleaks-allow", "--gitleaks-ignore-path", str(ignore),
        "--report-format=json", "--report-path=-", "--exit-code=23", "--timeout=60",
    ]
    result = subprocess.run(command, capture_output=True, timeout=65)
    if result.returncode not in (0, 23):
        raise ScanError("Gitleaks failed; commit blocked. Check installation and .gitleaks.toml.")
    try:
        report = json.loads(result.stdout or b"[]")
        findings = []
        if not isinstance(report, list):
            raise ValueError("Expected a findings list")
        for entry in report:
            name = Path(entry["File"])
            if name.is_absolute():
                name = name.relative_to(snapshot)
            findings.append((names[str(name)], int(entry["StartLine"]), str(entry["RuleID"])))
    except (ValueError, KeyError, TypeError) as error:
        raise ScanError("Gitleaks returned an invalid report; commit blocked.") from error
    if result.returncode == 23 and not findings:
        raise ScanError("Gitleaks reported an issue without locations; commit blocked.")
    return findings


def scan():
    entries = staged_entries()
    if not entries:
        print("Security check: no staged files to scan.")
        return 0
    dependencies()
    findings = []
    with tempfile.TemporaryDirectory(prefix="nomadfi-staged-security-") as directory:
        temp = Path(directory)
        snapshot = temp / "snapshot"
        snapshot.mkdir()
        names = {}
        for index, (name, mode, oid) in enumerate(entries):
            if private_path(name):
                findings.append((name, 0, "private-file"))
                continue
            if mode not in {"100644", "100755"}:
                findings.append((name, 0, "unscannable-symlink-or-submodule"))
                continue
            if int(git("cat-file", "-s", oid)) > MAX_FILE_BYTES:
                findings.append((name, 0, "file-exceeds-25-MiB-scan-limit"))
                continue
            data = git("cat-file", "blob", oid)
            findings.extend((name, line, rule) for line, rule in financial_findings(data))
            # Neutral filenames prevent built-in path exclusions from hiding staged secrets.
            scan_name = f"{index}.txt"
            names[scan_name] = name
            destination = snapshot / scan_name
            destination.write_bytes(data)
        findings.extend(gitleaks_findings(snapshot, temp, names))
    if findings:
        print("Commit blocked: review these staged locations (values are never printed):", file=sys.stderr)
        for name, line, rule in sorted(set(findings)):
            print(f"  {name!r}:{line} [{rule}]", file=sys.stderr)
        print("Remove private data from the staged version, then retry. See docs/CommitSecurity.md.", file=sys.stderr)
        return 1
    print(f"Security check passed: {len(entries)} staged files scanned locally.")
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-dependencies", action="store_true")
    args = parser.parse_args()
    try:
        if args.check_dependencies:
            dependencies()
            return 0
        return scan()
    except (ScanError, OSError, subprocess.TimeoutExpired) as error:
        print(str(error) if isinstance(error, ScanError) else "Security scanner failed; commit blocked.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
