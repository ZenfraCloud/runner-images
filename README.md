<!-- ABOUTME: What the runner images are, how they are named, tagged and patched, and how to build on them -->
<!-- ABOUTME: Per-flavour detail (contents, local build, release evidence) lives in images/<flavour>/README.md -->

# runner-images

Container images that Zenfra workers use as the sandbox for a run: every
hook command and every tool invocation of a run executes in a container
started from one of these images, with the run's workspace mounted.

They are public so you can read exactly what runs your code, and fork or
extend it.

## Flavours

Each flavour lives in `images/<flavour>/` and is published as its own package,
`ghcr.io/zenfracloud/zenfra-runner-<flavour>`, for `linux/amd64` and
`linux/arm64`.

| Flavour | Package | Contents |
|---|---|---|
| [`tf`](images/tf/README.md) | `ghcr.io/zenfracloud/zenfra-runner-tf` | Alpine 3.24 (digest-pinned) + `python3`, `py3-pip`, `curl`, `git`, `jq`, `ca-certificates` |

`tf` is a family name for OpenTofu and Terraform stacks. Neither binary is
baked into the image: the worker mounts the OpenTofu or Terraform binary the
stack asks for, read-only and on `PATH`.

## Tags

- `<YYYYMMDD>-<run id>-<attempt>`: a candidate, pushed by every build of
  `main`. Immutable in practice; never reused.
- `latest`: the last `main` build that passed the smoke test on both
  architectures and was promoted. Promotion re-points `latest` at the
  candidate's exact manifest (no rebuild), and only when the candidate was
  built from the current tip of `main`. So `latest` can lag `main` by a build
  and is never a digest that failed the smoke on either architecture.

For anything you depend on, pin the digest, not a tag:
`ghcr.io/zenfracloud/zenfra-runner-tf@sha256:…`.

## Patch cadence

The base image is pinned by digest and Dependabot proposes base and action
updates weekly. Every build also runs `apk upgrade` over the pinned base, so
packages it shipped with get their available fixes, not only the ones the
image adds. A scheduled build every Monday at 06:00 UTC rebuilds `main` with
the package layer uncached and publishes it like any other `main` build.

The build is not reproducible: packages resolve when the image is built, by
design. The published digest is the repeatable unit; pin it.

## Building on an image

```dockerfile
FROM ghcr.io/zenfracloud/zenfra-runner-tf@sha256:…
RUN apk add --no-cache aws-cli
```

What the sandbox does with your image, and what that means for it:

- It sets the user (`--user <worker uid:gid>`), the working directory (the
  project directory in the workspace) and `HOME` (inside the workspace), so a
  `USER`, `WORKDIR` or `HOME` in your image is overridden.
- It appends the command after the image name, which replaces any `CMD`.
- It never overrides `ENTRYPOINT`. Leave `ENTRYPOINT` unset: if you set one,
  it receives the sandbox's command as its arguments.
- Install system-wide at build time. Anything a hook installs at run time
  (a venv under `$HOME`, a downloaded binary in the workspace) lasts for one
  execution of the run: not across the handoff to the apply after approval,
  a retry or a requeue. Each execution installs again.

## Repository layout

```
images/<flavour>/{Dockerfile,smoke.sh,README.md}
scripts/flavours.sh                        # flavour list for the workflow matrices
scripts/promote.sh                         # the guarded promotion of a candidate to latest
.github/actions/publish-image/             # candidate build, smoke, scan, promote
.github/workflows/build.yml                # pull requests: build and smoke each flavour on both arches
.github/workflows/publish.yml              # main, weekly schedule, manual dispatch
```

A new flavour is a new `images/<flavour>/` directory with a `Dockerfile` and a
`smoke.sh <image> [platform]`; both workflows pick it up. It also needs a
Dependabot `docker` entry for its directory.

## License

[MIT](LICENSE)
