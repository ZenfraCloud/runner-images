#!/bin/sh
# ABOUTME: Points <image>:latest at a smoked candidate's exact manifest, only if it was built from main's tip
# ABOUTME: Usage: promote.sh <image> <candidate digest> <built sha> <smoke-passed>; git and docker come from PATH

set -eu

if [ $# -ne 4 ]; then
    echo "usage: promote.sh <image> <candidate digest> <built sha> <smoke-passed>" >&2
    exit 2
fi
image=$1 digest=$2 sha=$3 smoke=$4

# Writes promoted=true|false for the calling step when run under Actions.
result() { [ -z "${GITHUB_OUTPUT:-}" ] || echo "promoted=$1" >> "$GITHUB_OUTPUT"; }
result false

if [ "$smoke" != true ]; then
    echo "::error::smoke-passed is '$smoke', not 'true'; $image@$digest is not promoted"
    exit 1
fi
case $digest in
    sha256:*) ;;
    *) echo "::error::candidate digest '$digest' is not a sha256 digest"; exit 1 ;;
esac

# The newest main build owns latest: a candidate from a commit main has moved past stays
# published under its own tag, and latest waits for the newer build.
if ! git fetch --quiet origin main; then
    echo "::error::git fetch origin main failed; $image@$digest is not promoted"
    exit 1
fi
head=$(git rev-parse FETCH_HEAD)
if [ "$head" != "$sha" ]; then
    echo "::notice::main is at $head, candidate was built from $sha; latest left as is, candidate stays published"
    exit 0
fi

docker buildx imagetools create -t "$image:latest" "$image@$digest"
got=$(docker buildx imagetools inspect "$image:latest" --format '{{.Manifest.Digest}}')
if [ "$got" != "$digest" ]; then
    echo "::error::$image:latest is $got after promotion, expected $digest"
    exit 1
fi
result true
echo "promoted $image:latest -> $digest"
