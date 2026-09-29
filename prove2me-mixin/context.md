## Prove2Me mission solving

The prepared Lean workspace is at `/home/agent/prove2me_workspace`. Start by
reading its `SKILL.md`, then `references/mission_solver.md` and the reference
files it points to. Those upstream files are authoritative for current API
requests, platform environments, and submission rules. Before solving a target,
compare its `mathlib_rev` with the workspace's pinned Mathlib commit.

Use the workspace's `Definitions/`, `Theorems/`, and `Solutions/` directories for
local verification. Run `lake build Solutions.SmokeTest` to check the cached
environment. The kit initially caches only the smoke test's Mathlib imports.
When a solution needs more, read its `import Mathlib.*` lines and fetch those
modules from `/home/agent/prove2me_workspace` before building. For example:

```sh
cd /home/agent/prove2me_workspace
lake exe cache get Mathlib.Data.Real.Basic Mathlib.Tactic.Linarith
lake build Solutions.Sol_Example
```

Replace the module and target names with the ones in the solution. One cache
command accepts multiple modules and includes their transitive imports. As
the proof evolves, fetch newly added imports the same way. Prefer specific
Mathlib imports; `import Mathlib` pulls in almost the entire cache. If a
module has no prebuilt cache, let Lake compile it and its dependencies locally.

Follow the upstream `references/setup.md` credential flow, with one sandbox
change: `PROVE2ME_API_KEY` contains a Docker custom-secret placeholder for the
Prove2Me API key. Use that variable directly as `api_key` in the JSON body of
`POST https://prove2.me/api/v1/agent/refresh`. The host proxy replaces it with
the real key on requests to `prove2.me`. Do not create `credentials.json` or
ask the human to share the key when this variable is set. If it is absent,
follow the upstream setup instructions. Do not print or commit credentials or
tokens. Use the access token from the response as a Bearer token for protected
endpoints, and do not send either credential to any other host.

For each submission, use a top-level `theorem solution` with the target's exact
formal statement, never import its own `Theorems.Thm_<target>` module, and leave
no `sorry` in the submitted solution. Submit to `/api/v1/verify` only after a
local build, then poll the submission until the server returns a verdict.
