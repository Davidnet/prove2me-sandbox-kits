#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/agent
export PATH="$HOME/.elan/bin:$PATH"

workspace_rev=cb8d8291bc0edcb706d4e8a03814de78832f6503
mathlib_rev=0df444a360eaa60ab8c11dca51a86af692955474
lean_toolchain=leanprover/lean4:v4.33.1
workspace="$HOME/prove2me_workspace"

if ! command -v elan >/dev/null 2>&1; then
  curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/prove2me-elan-init.sh
  sh /tmp/prove2me-elan-init.sh -y --default-toolchain none
  rm /tmp/prove2me-elan-init.sh
fi

if [ ! -d "$workspace/.git" ]; then
  git clone https://github.com/prove2me/prove2me_workspace.git "$workspace"
  git -C "$workspace" checkout --detach "$workspace_rev"
fi

cd "$workspace"
if [ ! -e lean-toolchain ]; then
  printf '%s\n' "$lean_toolchain" > lean-toolchain
fi
if [ ! -e lakefile.lean ]; then
  cat > lakefile.lean <<EOF
import Lake
open Lake DSL
package «prove2me» where
  leanOptions := #[⟨\`autoImplicit, false⟩]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" @
  "$mathlib_rev"

lean_lib «Definitions» where
lean_lib «Theorems» where
@[default_target]
lean_lib «Solutions» where
EOF
fi

MATHLIB_NO_CACHE_ON_UPDATE=1 lake update
lake exe cache get Mathlib.Data.Real.Basic Mathlib.Tactic.Linarith
test "$(git -C .lake/packages/mathlib rev-parse HEAD)" = "$mathlib_rev"
lake build Solutions.SmokeTest
