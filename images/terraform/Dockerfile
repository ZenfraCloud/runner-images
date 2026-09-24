# ABOUTME: terraform runner image: pinned Alpine plus python3, pip, curl, git and jq; no Terraform binary baked in
# ABOUTME: Sandbox base for Zenfra workers; the sandbox supplies user, workdir, HOME and the command

# The apk stage is named "base" so a scheduled rebuild can re-run it with --no-cache-filter=base.
FROM alpine:3.24@sha256:294b683cb724975bec92580e1e685676bd4b50bda910ddb8c51d4cabeaec77e6 AS base

ARG VERSION=dev
ARG COMMIT=unknown

# dl-cdn.alpinelinux.org occasionally stalls an established connection and apk has no timeout
# of its own, so every attempt is bounded. upgrade patches what the pinned base shipped with,
# add installs the toolchain; both resolve at build time, so each published digest is the unit.
RUN i=0; while [ $i -lt 3 ]; do \
        timeout 90 apk update && \
        timeout 180 apk upgrade && \
        timeout 180 apk add \
            ca-certificates \
            curl \
            git \
            jq \
            py3-pip \
            python3 && break; \
        i=$((i+1)); echo "apk attempt $i failed; retrying in $((i*5))s"; sleep $((i*5)); \
    done; \
    rm -rf /var/cache/apk/*; \
    if [ $i -eq 3 ]; then echo "apk failed after 3 attempts"; exit 1; fi

# Hooks install into a venv under the workspace; no system-wide pip installs.
ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1

# base.name and base.digest are added at publish time from the FROM line above.
LABEL org.opencontainers.image.title="zenfra-runner-terraform" \
      org.opencontainers.image.source="https://github.com/ZenfraCloud/runner-images" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}"

# No USER, ENTRYPOINT or CMD: the sandbox passes --user and the command on every run.
