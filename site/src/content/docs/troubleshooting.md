---
title: Troubleshooting
description: Fixes for the most common CodeGraph issues.
---

## "CodeGraph not initialized"

Run `codegraph init` in your project directory first.

## Indexing is slow

Check that `node_modules` and other large directories are excluded (they are, if gitignored). Use `--quiet` to reduce output overhead.

## MCP hits `database is locked`

Current builds shouldn't: CodeGraph bundles its own Node runtime and uses Node's built-in `node:sqlite` in WAL mode, where concurrent reads never block on a writer. If you still see it:

- **You're on an old (pre-0.9) install.** Reinstall to get the bundled runtime — `curl -fsSL https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.sh | sh` (macOS/Linux), `irm https://raw.githubusercontent.com/colbymchenry/codegraph/main/install.ps1 | iex` (Windows), or `npm i -g @colbymchenry/codegraph@latest`.
- **`codegraph status` shows `Journal:` other than `wal`** — WAL couldn't be enabled on this filesystem (common on network shares and WSL2 `/mnt`), so reads can block on writes. Move the project (with its `.codegraph/` folder) onto a local disk.

## MCP server not connecting

Ensure the project is initialized/indexed, verify the path in your MCP config, and check that `codegraph serve --mcp` works from the command line.

## Agent config exists but tools do not appear

Restart the agent after `codegraph install`. Then run `codegraph doctor --target=<agent> --location=global` to verify the selected config, skill, MCP launch, and index.

## Missing symbols

The MCP server auto-syncs on save (wait a couple of seconds). Run `codegraph sync` manually if needed. Check that the file's language is [supported](/codegraph/reference/languages/) and isn't excluded by `.gitignore`.

## Skipped files

`codegraph status` and `codegraph_status` list files skipped intentionally, such as source files above the size limit. The index can still be up to date; inspect or split the skipped file only if your task depends on it.

## Node/runtime mismatch

Standalone installs and generated npm packages run the bundled runtime. Source checkouts require Node.js `>=22.5.0 <25.0.0`; run `codegraph doctor` to see which runtime is active.
