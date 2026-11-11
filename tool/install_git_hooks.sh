#!/bin/sh
set -eu

repo_root=$(git rev-parse --show-toplevel)
git -C "$repo_root" config core.hooksPath .githooks
printf 'Git hooks enabled for %s\n' "$repo_root"
