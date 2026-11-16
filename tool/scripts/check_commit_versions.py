#!/usr/bin/env python3
"""Require each pull request commit to change pubspec.yaml's version field."""

import re
import subprocess
import sys


VERSION_LINE = re.compile(r"(?m)^version:\s*([^\s#]+)")


def version_at(revision: str) -> str:
    try:
        content = subprocess.check_output(
            ["git", "show", f"{revision}:pubspec.yaml"], text=True
        )
    except subprocess.CalledProcessError as error:
        raise ValueError(f"Could not read pubspec.yaml at {revision}") from error

    match = VERSION_LINE.search(content)
    if not match:
        raise ValueError(f"No top-level version field in pubspec.yaml at {revision}")
    return match.group(1)


def commits_between(base: str, head: str) -> list[str]:
    output = subprocess.check_output(
        ["git", "rev-list", "--reverse", f"{base}..{head}"], text=True
    )
    return output.splitlines()


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: check_commit_versions.py BASE_SHA HEAD_SHA", file=sys.stderr)
        return 2

    base, head = sys.argv[1:]
    commits = commits_between(base, head)
    if not commits:
        print("No pull request commits found.", file=sys.stderr)
        return 1

    failures = []
    for commit in commits:
        parents = subprocess.check_output(
            ["git", "rev-list", "--parents", "-n", "1", commit], text=True
        ).split()
        if len(parents) < 2:
            failures.append((commit, "commit has no parent"))
            continue

        parent = parents[1]
        before = version_at(parent)
        after = version_at(commit)
        if before == after:
            failures.append((commit, f"version remains {after}"))
        else:
            print(f"{commit[:12]}: {before} -> {after}")

    if failures:
        print("Every commit in a PR targeting main must change pubspec.yaml version:")
        for commit, reason in failures:
            print(f"  {commit[:12]}: {reason}")
        return 1

    print(f"All {len(commits)} commit(s) change pubspec.yaml version.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
