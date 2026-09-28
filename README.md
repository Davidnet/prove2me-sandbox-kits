# Prove2Me Sandbox Kits

This repository contains a small v3 Lean mixin and two v3 workloads. The mixin
pins Prove2Me's default Lean 4 environment. During first sandbox creation, its
install hook downloads Lean and Mathlib's prebuilt `.olean` cache and runs a
smoke test. The shell workload is for local verification; the Claude Code
workload runs the agent.

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

Set the Anthropic service secret on the host, then create the sandbox:

```sh
sbx secret set anthropic
sbx create --name p2m-claude docker.io/davidnet/prove2me-claude-set:0.1.1
```

Prove2Me's `POST /agent/refresh` takes its `p2m_` API key in a JSON body.
Docker's custom-secret proxy substitutes secrets in request headers, so it
cannot supply that body field. Follow Prove2Me's
[credential setup](https://github.com/prove2me/prove2me_workspace/blob/main/references/setup.md)
inside the sandbox. To enter an existing API key without placing it in shell
history, open `sbx exec -it p2m-claude bash` and run:

```sh
cd /home/agent/prove2me_workspace
umask 077
read -rsp 'Prove2Me API key: ' P2M_KEY; printf '\n'
jq -n --arg api_key "$P2M_KEY" '{api_key: $api_key}' > credentials.json
unset P2M_KEY
```

The upstream workspace ignores `credentials.json` in Git. Keep it inside the
sandbox and never copy it into this repository. Confirm `/agent/refresh`
succeeds before mission work, then start the agent with
`sbx run --name p2m-claude`. The key is stored in the sandbox, so use a dedicated sandbox for
trusted agents.

For local source development, create the sandbox with
`sbx create --name p2m-claude ./prove2me-claude --kit ./prove2me-mixin`.

To select another Claude model, add
`--kit-arg prove2me-claude.model=opus` (or `haiku`) to `sbx run`.

## Published v0.1.1

The following Docker Hub images are published for both `linux/amd64` and
`linux/arm64`:

- `docker.io/davidnet/prove2me-mixin:0.1.1` — Lean setup for other workloads.
- `docker.io/davidnet/prove2me-claude:0.1.1` — Claude workload component.
- `docker.io/davidnet/prove2me-claude-set:0.1.1` — ready-to-run combination.

After creating the sandbox and setting up its Prove2Me key as described above,
run the published set with:

```sh
sbx run docker.io/davidnet/prove2me-claude-set:0.1.1 --name p2m-claude
```

The first run downloads and installs the pinned Lean workspace into that
sandbox. To use the mixin with a different agent, run, for example,
`sbx run codex --kit docker.io/davidnet/prove2me-mixin:0.1.1`.

The published Prove2Me `SKILL.md` in the workspace is the source of truth for
API details and submission rules. After publishing both v3 images to a
registry, generate and build a kit set using their published references:

```sh
docker buildx build -f prove2me-mixin/prove2me-mixin.yaml \
  -t docker.io/YOUR_NAMESPACE/prove2me-mixin:0.1.1 \
  --push prove2me-mixin
docker buildx build -f prove2me-claude/prove2me-claude.yaml \
  -t docker.io/YOUR_NAMESPACE/prove2me-claude:0.1.1 \
  --push prove2me-claude
bash prove2me-claude-set/generate.sh \
  docker.io/YOUR_NAMESPACE/prove2me-claude:0.1.1 \
  docker.io/YOUR_NAMESPACE/prove2me-mixin:0.1.1
docker buildx build -f prove2me-claude-set/prove2me-claude-set.yaml \
  -t docker.io/YOUR_NAMESPACE/prove2me-claude-set:0.1.1 \
  --push prove2me-claude-set
```

Docker requires published registry references for a set's `kits:` entries;
local directories work directly with `sbx run ... --kit ...`. The generated
descriptor is not committed because its references depend on your registry.
