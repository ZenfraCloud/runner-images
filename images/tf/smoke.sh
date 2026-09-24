#!/bin/sh
# ABOUTME: Offline smoke of a runner image under the worker sandbox's shape (uid 1000, relative HOME)
# ABOUTME: Usage: smoke.sh <image> [platform]; checks go in on stdin so only a named volume is shared

set -eu

image=$1
platform=${2:+--platform $2}
vol=zenfra-runner-smoke-$$

trap 'docker volume rm -f "$vol" >/dev/null' EXIT
docker volume create "$vol" >/dev/null

# The worker's workspace is owned by the worker's UID:GID (1000:1000).
# shellcheck disable=SC2086
docker run --rm $platform --network none -v "$vol:/workspace" "$image" \
    sh -c 'mkdir -p /workspace/proj && chown -R 1000:1000 /workspace'

sandbox() {
    # shellcheck disable=SC2086
    docker run --rm -i $platform --network none --user 1000:1000 \
        -v "$vol:/workspace" -w /workspace/proj -e HOME=.zenfra/home "$image" sh -s
}

# Container 1: the toolchain, and a venv in the workspace.
sandbox <<'CHECKS'
set -eux
test "$(id -u):$(id -g)" = 1000:1000
python3 -m pip --version
git --version
curl --version
jq --version
test -s /etc/ssl/certs/ca-certificates.crt
python3 -m venv "$HOME/venv"
"$HOME/venv/bin/python" -m pip --version
echo ok > "$HOME/sentinel"
CHECKS

# Container 2: a fresh container sees what container 1 left in the workspace.
sandbox <<'CHECKS'
set -eux
"$HOME/venv/bin/python" -c 'import json, ssl, sys; print(sys.prefix)'
test "$(cat "$HOME/sentinel")" = ok
CHECKS

echo "smoke ok: $image ${2:-}"
