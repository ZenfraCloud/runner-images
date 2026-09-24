#!/bin/sh
# ABOUTME: Smoke test for the terraform image; the shared checks live in scripts/smoke.sh
# ABOUTME: Usage: smoke.sh <image> [platform]; add terraform-specific checks here when the image gains extras

exec "$(dirname "$0")/../../scripts/smoke.sh" "$@"
