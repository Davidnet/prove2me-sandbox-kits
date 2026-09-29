# Prove2Me Sandbox Kits

This repository contains a v3 Lean mixin and a local shell workload. For Claude
Code, use the mixin with [Docker's v3 Claude workload](https://hub.docker.com/r/docker/sbx-kit-claude).
The mixin pins Prove2Me's default Lean 4 environment. During first sandbox
creation, its install hook downloads Lean and Mathlib's prebuilt `.olean` cache
and runs a smoke test.

The workspace snapshot and Mathlib revision are pinned in
`prove2me-mixin/bootstrap.sh`. A target theorem may use a different
environment. Check its `mathlib_rev` before relying on the bundled cache.

## Build and test

Docker Desktop, Buildx, and `sbx` v0.45 or later are required. Build the mixin
from its YAML descriptor, rather than invoking its Dockerfile directly:

```sh
docker buildx build -f prove2me-mixin/prove2me-mixin.yaml \
  -t prove2me-mixin:dev prove2me-mixin
```

The mixin image contains only the bootstrap script and instructions. The first
`sbx` creation installs Lean and caches the two Mathlib modules used by the
smoke test, including their imports. Before building a mission solution with
other Mathlib imports, run `lake exe cache get <module names>` in the workspace,
using the names from the solution's `import` lines. Pass several modules in one
command; their transitive imports are included. Then run `lake build` for the
solution target. The agent receives this workflow in its context. Prefer
specific imports over `import Mathlib`, which would pull in most of the cache.
Restarts reuse installed files; a new sandbox has its own Lean and Mathlib
installation.

Create an interactive shell sandbox with the mixin:

```sh
sbx run ./prove2me-shell --kit ./prove2me-mixin --name p2m-shell
```

Inside it, run:

```sh
cd /home/agent/prove2me_workspace
elan --version
lake build Solutions.SmokeTest
curl -fsS https://prove2.me/api/v1/health
```

The mixin's network capability applies during sandbox installation and at
runtime. A plain `docker run` of the image does not apply it.

## Credentials and mission work

Set up both credentials on the host, then create the sandbox. The Prove2Me key
is stored as a [Docker custom secret](https://docs.docker.com/ai/sandboxes/configuration/credentials/#custom-secrets)
scoped to `p2m-claude` and `prove2.me`:

```bash
sbx secret set anthropic
(
  read -rsp 'Prove2Me API key: ' P2M_KEY || exit 1
  printf '\n'
  sbx secret set-custom --sandbox p2m-claude --host prove2.me \
    --env PROVE2ME_API_KEY --placeholder 'p2m_{rand}' --value "$P2M_KEY"
) && sbx create --name p2m-claude docker.io/docker/sbx-kit-claude:2.1.267 \
  --kit docker.io/davidnet/prove2me-mixin:0.1.2
```

If `p2m-claude` already exists from an earlier version, use a new sandbox name
in the `--sandbox`, `--name`, and `sbx run` commands; an existing sandbox keeps
its original kit version.

Run `sbx run --name p2m-claude` to start the agent. The sandbox receives a
`p2m_` placeholder in `PROVE2ME_API_KEY`, not the real key. The agent can use
that variable directly as `api_key` in the JSON body of
`POST https://prove2.me/api/v1/agent/refresh`. Docker's proxy replaces the
placeholder on the outbound request to `prove2.me`. This avoids creating a
`credentials.json` file. Ask the agent to confirm refresh succeeds before
mission work.

The `--value` command avoids shell history, but the real key can briefly appear
in the host process list. If it is in 1Password or AWS Secrets Manager, use
Docker's `--ref` option instead.

For local source development, run Docker's v3 Claude workload with the mixin:

```sh
sbx create --name p2m-claude docker.io/docker/sbx-kit-claude:2.1.267 \
  --kit ./prove2me-mixin
```

To select another Claude model, pass `-- --model opus` (or `haiku`) to `sbx run`.

## Published kits

`docker.io/davidnet/prove2me-mixin:0.1.2` is published for both `linux/amd64`
and `linux/arm64`. The initial `sbx create` downloads and installs the pinned
Lean workspace into that sandbox. The published Prove2Me `SKILL.md` in the
workspace is the source of truth for API details and submission rules.

To publish your own mixin:

```sh
docker buildx build -f prove2me-mixin/prove2me-mixin.yaml \
  -t docker.io/YOUR_NAMESPACE/prove2me-mixin:0.1.2 \
  --push prove2me-mixin
```
