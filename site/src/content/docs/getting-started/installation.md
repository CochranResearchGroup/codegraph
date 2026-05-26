---
title: Installation
description: Install CodeGraph and configure your AI coding agents.
---

## 1. Run the installer

```bash
npx @colbymchenry/codegraph
```

The installer will:

- Ask which agent(s) to configure — auto-detecting installed ones from **Claude Code**, **Cursor**, **Codex CLI**, **opencode**, and **Hermes Agent**.
- Prompt to install `codegraph` on your `PATH` (so agents can launch the MCP server).
- Ask whether configs apply to all your projects or just this one.
- Write each chosen agent's MCP server config plus an instructions file (e.g. `CLAUDE.md`, `.cursor/rules/codegraph.mdc`, `~/.codex/AGENTS.md`).
- Install the `codegraph-workspace` agent skill for global installs (`~/.agents/skills/codegraph-workspace`).
- Set up auto-allow permissions when Claude Code is one of the targets.
- Initialize your current project (local installs only).

## Non-interactive (scripting / CI)

```bash
codegraph install --target=codex --location=global --yes  # Codex CLI, non-interactive
codegraph install --yes                                   # auto-detect agents, install global
codegraph install --target=cursor,codex --yes             # explicit target list
codegraph install --target=auto --location=local     # detected agents, project-local
codegraph install --print-config codex               # print snippet, no file writes
```

| Flag | Values | Default |
|---|---|---|
| `--target` | `auto`, `all`, `none`, or csv (`claude,cursor,…`) | prompt |
| `--location` | `global`, `local` | prompt |
| `--yes` | (boolean) | prompt every step |
| `--no-permissions` | (boolean) skip Claude auto-allow list | permissions on |
| `--print-config <id>` | dump snippet for one agent and exit | — |

## 2. Restart your agent

Restart your agent (Claude Code / Cursor / Codex CLI / opencode / Hermes Agent) for the MCP server to load.

## 3. Initialize projects

```bash
cd your-project
codegraph init -i
```

This builds the per-project knowledge graph index and wires up any project-local agent surfaces, so a single global `codegraph install` works in every project you open.

## 4. Verify install health

```bash
codegraph doctor --target=codex --location=global
```

`doctor` checks the runtime, bundled product assets, installed skill, selected agent config, index freshness, and a real MCP `codegraph_status` smoke. Use `--json` for release validation or CI.

Global installs also place the `codegraph-workspace` skill in your user skill root. Skill-aware agents use it to check `codegraph_status`, sync stale indexes, prefer structural graph tools over grep/read, and report skipped or oversized files.

If a source file is above CodeGraph's size limit, the index records it as a skipped file instead of leaving the project permanently stale. `codegraph status` and `codegraph_status` show the skipped-file caveat while still reporting the index as up to date when everything else is current.

## Supported platforms

Every release ships a self-contained build (bundled Node runtime — nothing to compile) for all three desktop OSes, on both x64 and arm64:

| Platform | Architectures | Install |
|---|---|---|
| Windows | x64, arm64 | PowerShell installer or npm |
| macOS | x64, arm64 | shell installer or npm |
| Linux | x64, arm64 | shell installer or npm |

## Uninstall

Changed your mind? One command removes CodeGraph from every agent it configured:

```bash
codegraph uninstall
```

This reverses the installer — stripping CodeGraph's MCP server config, instructions, and permissions from configured agents. A global uninstall also removes the user-level `codegraph-workspace` skill. Your project indexes (`.codegraph/`) are left untouched; remove those per-project with `codegraph uninit`. Use `--target` to remove from specific agents, or `--yes` to run non-interactively.
