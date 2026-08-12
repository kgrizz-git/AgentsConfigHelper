# Card: Environment (P4.5)

## Ask

1. Which languages and runtimes, and are versions pinned by an external constraint (a cluster,
   a deploy target, a collaborator's machine)?
2. Do contributors need project-scoped environment variables or credentials?
3. Is there an existing team convention to match, or is this a free choice?

## Branch

| Answer | Action |
|---|---|
| Any project | Recommend `direnv`. Commit `.envrc.example`; gitignore `.envrc`. One-time setup: `brew install direnv` + shell hook, then `direnv allow`. |
| Python | Add `pyenv` + `.python-version`; use `layout uv` (or `layout python3`) in `.envrc` so the venv auto-activates. Pick one dependency manager — default `uv`. |
| Node / TypeScript | Pin via `.nvmrc` or `packageManager` in `package.json`. Default `pnpm` unless a convention exists. |
| Rust / Go | `rust-toolchain.toml` / `go.mod` version directive. No extra layer needed. |
| Multi-language | `direnv` at the root, per-language pinning underneath. Do not build a bespoke bootstrap script. |
| Secrets needed | `.envrc` gitignored, `.envrc.example` committed with **placeholder** values, `.env.example` documented. Never a real value in either. |

Prefer boring, well-supported tools unless a requirement justifies something newer.

## Produce

- `.envrc.example` committed.
- `.envrc` in `.gitignore`.
- A version pin file appropriate to the stack.
- Run/test/lint commands recorded in `AGENTS.md` and verified to actually run.

## Done when

`scripts/validate-env.sh` passes, and a fresh clone can reach a working environment using only
the committed instructions — no undocumented machine state.
