[![tests](https://github.com/YOUR_GITHUB_USER/ddev-zed/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/YOUR_GITHUB_USER/ddev-zed/actions/workflows/tests.yml?query=branch%3Amain)

# DDEV Zed

Zed editor integration for DDEV projects: tasks for everyday `ddev` commands and a ready-to-use Xdebug listener.

## Install

```bash
ddev add-on get YOUR_GITHUB_USER/ddev-zed
```

Opt in to the DDEV MCP server for Zed's Agent Panel (creates `.zed/settings.json` only if it doesn't exist):

```bash
DDEV_ZED_MCP=true ddev add-on get YOUR_GITHUB_USER/ddev-zed
```

## What it installs

| File | Purpose |
|---|---|
| `.zed/tasks.json` | start, stop, restart, describe, launch, mailpit, ssh, logs, xdebug toggle/diagnose, composer install, snapshot |
| `.zed/debug.json` | "DDEV: Listen for Xdebug" on port 9003, `/var/www/html` mapped to the project root |
| `.zed/settings.json` | optional `ddev-mcp` context server |

Canonical copies live in `.ddev/zed/`.

## Ownership

Files containing `#ddev-generated` belong to the add-on and are updated on reinstall. Delete that line to take ownership; the add-on will then skip the file on install and keep it on removal.

## Debugging

1. Start "DDEV: Listen for Xdebug" from the debug panel.
2. Run the `ddev: xdebug toggle` task.
3. Load the page.

`pathMappings` uses the absolute project path (written at install time) because `$ZED_WORKTREE_ROOT` does not resolve reliably there. If you move the project, re-run `ddev add-on get`.

## Keybindings

Zed's `keymap.json` is global, so the add-on doesn't touch it. Example:

```json
[
  {
    "context": "Workspace",
    "bindings": {
      "ctrl-alt-d s": ["task::Spawn", { "task_name": "ddev: start" }],
      "ctrl-alt-d x": ["task::Spawn", { "task_name": "ddev: xdebug toggle" }],
      "ctrl-alt-d h": ["task::Spawn", { "task_name": "ddev: ssh" }]
    }
  }
]
```

## Remove

```bash
ddev add-on remove zed
```

**Contributed and maintained by [@YOUR_GITHUB_USER](https://github.com/YOUR_GITHUB_USER)**
