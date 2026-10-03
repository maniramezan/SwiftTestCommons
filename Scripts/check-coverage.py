#!/usr/bin/env python3
"""Enforce line coverage for each product and for lines changed since a base revision.

Run after `swift test --enable-code-coverage`:

    python3 Scripts/check-coverage.py --diff-base origin/main

Per-target floors stop overall coverage from regressing. The diff check requires
changed executable lines in Sources/ to be exercised by tests, and annotates each
uncovered changed line when running in GitHub Actions.
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "Sources"

# Minimum line coverage (percent) for each target's sources. Raise these as tests
# improve; never lower them to make a pull request pass.
TARGET_THRESHOLDS = {
    "TestCommons": 97.0,
    "TestCommonsUI": 95.0,
    # XCUIElement-driven waits need a UI-test host application; this floor covers the
    # pure logic extracted from them and keeps new untested code from lowering it.
    "TestCommonsXCUI": 35.0,
}
# Targets added later must meet this floor until they get an explicit entry.
DEFAULT_TARGET_THRESHOLD = 95.0

# Minimum coverage (percent) of executable lines changed relative to --diff-base.
DIFF_THRESHOLD = 90.0
# Targets whose changed lines cannot be exercised by `swift test` alone.
DIFF_EXEMPT_TARGETS = {"TestCommonsXCUI"}


def run(command, **kwargs):
    return subprocess.run(command, cwd=ROOT, check=True, text=True, capture_output=True, **kwargs).stdout


def llvm_cov():
    if sys.platform == "darwin":
        return ["xcrun", "llvm-cov"]
    if shutil.which("llvm-cov"):
        return ["llvm-cov"]
    raise SystemExit("llvm-cov was not found on PATH")


def test_binaries(bin_path):
    binaries = []
    for bundle in sorted(bin_path.glob("*.xctest")):
        # Apple platforms build bundles; Linux builds a single executable.
        executable = bundle / "Contents" / "MacOS" / bundle.stem
        binaries.append(executable if executable.exists() else bundle)
    if not binaries:
        raise SystemExit(f"No test binaries in {bin_path}; run `swift test --enable-code-coverage` first")
    return binaries


def line_counts():
    """Returns {source path: {line: execution count}} for files under Sources/."""
    bin_path = Path(run(["swift", "build", "--show-bin-path"]).strip())
    profile = bin_path / "codecov" / "default.profdata"
    if not profile.exists():
        raise SystemExit(f"Missing {profile}; run `swift test --enable-code-coverage` first")
    binaries = test_binaries(bin_path)
    stale = [b.name for b in binaries if b.stat().st_mtime > profile.stat().st_mtime]
    if stale:
        raise SystemExit(
            "Coverage data is older than " + ", ".join(stale)
            + "; rerun `swift test --enable-code-coverage` without --filter"
        )

    objects = [str(binaries[0])] + [arg for b in binaries[1:] for arg in ("-object", str(b))]
    lcov = run(llvm_cov() + [
        "export", "-format=lcov", "-instr-profile", str(profile),
        r"-ignore-filename-regex=(\.build|Tests)/", *objects,
    ])

    counts = {}
    current = None
    for line in lcov.splitlines():
        if line.startswith("SF:"):
            path = Path(line[3:]).resolve()
            current = counts.setdefault(path, {}) if SOURCES in path.parents else None
        elif line.startswith("DA:") and current is not None:
            number, count = line[3:].split(",")[:2]
            current[int(number)] = max(current.get(int(number), 0), int(count))
    if not counts:
        raise SystemExit("No coverage was recorded for Sources/")
    return counts


def target_of(path):
    return path.relative_to(SOURCES).parts[0]


def percent(covered, total):
    return 100.0 if total == 0 else 100.0 * covered / total


def changed_lines(base):
    """Returns {source path: {line}} added or modified since the merge base with `base`."""
    diff = run(["git", "diff", "--unified=0", "--no-color", "--merge-base", base, "--", "Sources"])
    changes = {}
    current = None
    for line in diff.splitlines():
        if line.startswith("+++ "):
            current = None if line == "+++ /dev/null" else changes.setdefault((ROOT / line[6:]).resolve(), set())
        elif line.startswith("@@") and current is not None:
            match = re.match(r"@@ -\S+ \+(\d+)(?:,(\d+))? @@", line)
            start, length = int(match.group(1)), int(match.group(2) or "1")
            current.update(range(start, start + length))
    # New files that are not yet tracked are entirely changed when checking locally.
    untracked = run(["git", "ls-files", "--others", "--exclude-standard", "--", "Sources"])
    for name in untracked.splitlines():
        path = (ROOT / name).resolve()
        changes[path] = set(range(1, len(path.read_text().splitlines()) + 1))
    return changes


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--diff-base", help="Revision to compare against, such as origin/main")
    arguments = parser.parse_args()

    counts = line_counts()
    failures = []
    summary = ["## Coverage", "", "| Target | Lines | Coverage | Required |", "|---|---|---|---|"]

    totals = {}
    for path, lines in counts.items():
        covered, total = totals.get(target_of(path), (0, 0))
        totals[target_of(path)] = (covered + sum(1 for c in lines.values() if c > 0), total + len(lines))
    for target in sorted({p.name for p in SOURCES.iterdir() if p.is_dir()}):
        covered, total = totals.get(target, (0, 0))
        required = TARGET_THRESHOLDS.get(target, DEFAULT_TARGET_THRESHOLD)
        value = percent(covered, total)
        status = "✅" if value >= required else "❌"
        print(f"{status} {target}: {value:.2f}% ({covered}/{total} lines), requires {required:.2f}%")
        summary.append(f"| {status} {target} | {covered}/{total} | {value:.2f}% | {required:.2f}% |")
        if value < required:
            failures.append(f"{target} line coverage {value:.2f}% is below {required:.2f}%")

    if arguments.diff_base:
        covered = total = 0
        uncovered = []
        for path, lines in sorted(changed_lines(arguments.diff_base).items()):
            if SOURCES not in path.parents or target_of(path) in DIFF_EXEMPT_TARGETS:
                continue
            executable = counts.get(path, {})
            for number in sorted(lines & executable.keys()):
                total += 1
                if executable[number] > 0:
                    covered += 1
                else:
                    uncovered.append((path.relative_to(ROOT), number))
        value = percent(covered, total)
        status = "✅" if value >= DIFF_THRESHOLD else "❌"
        print(f"{status} Changed lines: {value:.2f}% ({covered}/{total}), requires {DIFF_THRESHOLD:.2f}%")
        summary += ["", f"{status} Changed lines since `{arguments.diff_base}`: {covered}/{total} ({value:.2f}%)"]
        for path, number in uncovered:
            print(f"  uncovered: {path}:{number}")
            if os.environ.get("GITHUB_ACTIONS"):
                print(f"::warning file={path},line={number}::Changed line is not covered by tests")
        if value < DIFF_THRESHOLD:
            failures.append(f"changed-line coverage {value:.2f}% is below {DIFF_THRESHOLD:.2f}%")

    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as stream:
            stream.write("\n".join(summary) + "\n")
    if failures:
        raise SystemExit("Coverage check failed:\n" + "\n".join(f"- {f}" for f in failures))


if __name__ == "__main__":
    main()
