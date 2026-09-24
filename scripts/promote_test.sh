#!/bin/sh
# ABOUTME: Tests promote.sh against a stub docker on PATH and a throwaway local git remote
# ABOUTME: Usage: sh scripts/promote_test.sh; prints each case and exits non-zero on the first failure

set -eu

promote=$(cd "$(dirname "$0")" && pwd)/promote.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# docker stub: logs every call; imagetools create remembers the source, inspect reports it
# (or $STUB_LATEST when set, to simulate a registry that did not take the new tag).
mkdir "$tmp/bin"
cat > "$tmp/bin/docker" <<'STUB'
#!/bin/sh
echo "$*" >> "$STUB_DIR/calls"
case "$*" in
    "buildx imagetools create -t "*) echo "${6#*@}" > "$STUB_DIR/latest" ;;
    "buildx imagetools inspect "*) if [ -n "${STUB_LATEST:-}" ]; then echo "$STUB_LATEST"; else cat "$STUB_DIR/latest"; fi ;;
esac
STUB
chmod +x "$tmp/bin/docker"
PATH=$tmp/bin:$PATH
export PATH STUB_DIR="$tmp"

git init -q --bare -b main "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
git -c user.name=t -c user.email=t@t commit -q --allow-empty -m one
git push -q origin main
built=$(git rev-parse HEAD)

img=ghcr.io/example/runner
dig=sha256:1111111111111111111111111111111111111111111111111111111111111111
fails=0

# check <name> <want exit> <want promoted> <want create calls> -- <promote.sh args>
check() {
    name=$1 want_rc=$2 want_promoted=$3 want_creates=$4
    shift 5
    : > "$tmp/calls"
    : > "$tmp/out"
    rc=0
    GITHUB_OUTPUT=$tmp/out "$promote" "$@" > "$tmp/log" 2>&1 || rc=$?
    creates=$(grep -c 'imagetools create' "$tmp/calls" || true)
    promoted=$(sed -n 's/^promoted=//p' "$tmp/out" | tail -n 1)
    if [ "$rc" = "$want_rc" ] && [ "$promoted" = "$want_promoted" ] && [ "$creates" = "$want_creates" ]; then
        echo "ok   $name"
    else
        echo "FAIL $name: exit $rc (want $want_rc), promoted '$promoted' (want $want_promoted), creates $creates (want $want_creates)"
        sed 's/^/     /' "$tmp/log"
        fails=1
    fi
}

check "fresh head promotes" 0 true 1 -- "$img" "$dig" "$built" true
grep -qx "buildx imagetools create -t $img:latest $img@$dig" "$tmp/calls" || { echo "FAIL create args: $(cat "$tmp/calls")"; fails=1; }
grep -q "imagetools inspect $img:latest" "$tmp/calls" || { echo "FAIL latest not verified"; fails=1; }

STUB_LATEST=sha256:2222222222222222222222222222222222222222222222222222222222222222 \
    check "latest mismatch after promotion fails" 1 false 1 -- "$img" "$dig" "$built" true

check "smoke-passed false" 1 false 0 -- "$img" "$dig" "$built" false
check "smoke-passed empty" 1 false 0 -- "$img" "$dig" "$built" ""
check "smoke-passed missing" 2 "" 0 -- "$img" "$dig" "$built"

git -c user.name=t -c user.email=t@t commit -q --allow-empty -m two
git push -q origin main
check "advanced head skips" 0 false 0 -- "$img" "$dig" "$built" true
grep -q '::notice::' "$tmp/log" || { echo "FAIL advanced head: no skip annotation"; fails=1; }

git remote set-url origin "$tmp/missing.git"
check "fetch failure" 1 false 0 -- "$img" "$dig" "$(git rev-parse HEAD)" true

exit "$fails"
