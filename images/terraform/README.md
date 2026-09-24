<!-- ABOUTME: What the terraform runner image contains, how to build and smoke it locally, and its release evidence -->
<!-- ABOUTME: Tags, patch cadence and the customization guide live in the repository README -->

# zenfra-runner-terraform

Sandbox base for Zenfra workers running Terraform stacks: Alpine
3.24 (digest-pinned) plus `python3`, `py3-pip`, `curl`, `git`, `jq` and
`ca-certificates`. No USER, ENTRYPOINT or CMD of its own (the sandbox passes
its own user and command).

The `terraform` binary is not in the image: the worker downloads the version the
stack asks for and mounts it read-only on `PATH`, and the smoke test asserts
that none is baked in. No scanners either: hooks install them into the
workspace, for example into a venv under `$HOME`.

Its contents are currently the same as `zenfra-runner-opentofu`; the two are
separate packages so each can gain tool-specific extras. A worker uses one
sandbox image for every run it executes, whichever tool the stack uses, so
either image runs either tool today.

Published as `ghcr.io/zenfracloud/zenfra-runner-terraform` for `linux/amd64` and
`linux/arm64`; see the [repository README](../../README.md) for tags and
the patch cadence.

## Build and smoke locally

```bash
for p in amd64 arm64; do
  docker buildx build --platform linux/$p --load -t zenfra-runner-terraform:local-$p images/terraform
  images/terraform/smoke.sh zenfra-runner-terraform:local-$p linux/$p
done
```

`smoke.sh` runs the image the way the sandbox does
(`--network none --user 1000:1000 -w /workspace/proj -e HOME=.zenfra/home`)
on a throwaway named volume: the first container checks the toolchain and
creates a venv under `$HOME`, the second, fresh container uses that venv. It
needs no network and no host path, so it works against a remote or
Docker-in-Docker daemon.

## Release evidence

Base `alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6`
(3.24.2), local build recorded 2026-09-24 on an arm64 host (amd64 under
emulation).

| | linux/amd64 | linux/arm64 |
|---|---|---|
| Python / pip (system) | 3.14.7 / 26.1.2 | 3.14.7 / 26.1.2 |
| pip in a fresh venv | 26.2.1 | 26.2.1 |
| git / curl / jq | 2.54.0 / 8.22.0 / 1.8.2 | 2.54.0 / 8.22.0 / 1.8.2 |
| Image size (`docker image inspect`) | 30.6 MB | 30.9 MB |
| Root filesystem (`du -sxm /`) | 80 MiB | 83 MiB |
| `smoke.sh` | pass | pass |

Packages resolve at build time, so a later build can differ; each published
digest is what was smoked.
