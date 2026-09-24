#!/bin/sh
# ABOUTME: Prints the sorted JSON array of image flavours: every images/<flavour>/ holding a Dockerfile
# ABOUTME: Single source of the workflow matrices; exits non-zero when there are none

set -eu

cd "$(dirname "$0")/../images"
list=$(for f in */Dockerfile; do [ -f "$f" ] && printf '"%s"\n' "${f%/Dockerfile}"; done | LC_ALL=C sort | paste -sd, -)
[ -n "$list" ] || { echo "no images/*/Dockerfile found" >&2; exit 1; }
echo "[$list]"
