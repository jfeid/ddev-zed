[![tests](https://github.com/jfeid/ddev-zed/actions/workflows/tests.yml/badge.svg?branch=main)](https://github.com/jfeid/ddev-zed/actions/workflows/tests.yml?query=branch%3Amain)

# DDEV Zed

Zed editor integration for DDEV projects: tasks for everyday `ddev` commands, a ready-to-use Xdebug listener, and a `ddev zed` command to open the project.

## Install

```bash
ddev add-on get jfeid/ddev-zed
```

To also connect Zed's Agent Panel to DDEV, opt in to the MCP server (see [DDEV MCP server](#ddev-mcp-server-optional)):

```bash
DDEV_ZED_MCP=true ddev add-on get jfeid/ddev-zed
```

## Requirements

- DDEV v1.25.4 or newer.
- Zed with the **PHP** extension. The extension provides the Xdebug debug adapter; without it the debug picker shows "No matches" for the add-on's config. Its default language server, phpactor, needs `php` on the machine running Zed. DDEV projects usually have PHP only in the container, so either switch the project to intelephense in `.zed/settings.json`:

  ```json
  { "languages": { "PHP": { "language_servers": ["intelephense", "!phpactor"] } } }
  ```

  or install a host PHP (`sudo apt install php-cli`).
- Node.js 20+ with npm on the machine running Zed, only if you opt in to the MCP server. On Ubuntu that means `sudo apt install nodejs npm`, since the `nodejs` package alone has no `npx`.

## What it installs

| File | Purpose |
|---|---|
| `.zed/tasks.json` | start, stop, restart, describe, launch, mailpit, ssh, logs, xdebug toggle/diagnose, composer install, snapshot |
| `.zed/debug.json` | "DDEV: Listen for Xdebug" on port 9003, `/var/www/html` mapped to `$ZED_WORKTREE_ROOT` |
| `.ddev/commands/host/zed` | `ddev zed` opens the project in Zed; extra arguments are passed through, e.g. `ddev zed -n` for a new window |
| `.zed/settings.json` | optional: registers the [`ddev-mcp`](https://www.npmjs.com/package/ddev-mcp) context server for the Agent Panel (only with `DDEV_ZED_MCP=true`) |

Canonical copies live in `.ddev/zed/`.

## DDEV MCP server (optional)

Setting `DDEV_ZED_MCP=true` during install writes `.zed/settings.json` with a `context_servers` entry that runs [`ddev-mcp`](https://www.npmjs.com/package/ddev-mcp) ([source](https://github.com/codingsasi/ddev-mcp)) via `npx -y ddev-mcp`. Nothing is installed at that moment: `npx` downloads the package the first time Zed starts the server, so Node.js 20+ must be available on your `PATH`.

`ddev-mcp` is a [Model Context Protocol](https://modelcontextprotocol.io/) server that exposes DDEV as tools. Once Zed loads it, the Agent Panel can:

- start, stop, restart the project and read `ddev describe` output
- read container logs
- import, export and snapshot the database
- run any command inside the web container through `ddev_exec` (composer, drush, wp-cli, artisan, phpunit, ...)

so you can ask the agent things like "restart ddev and run the migrations" instead of switching to a terminal. The server runs commands in the project the Agent Panel is open in.

This works with Zed's built-in agent and with external agents such as Claude Code running inside Zed. Zed forwards its configured context servers to external agents, so a Claude Code thread started from the Agent Panel sees the same `ddev_*` tools. The built-in agent needs a model first: Zed's free plan doesn't include one, so add an API key under Configure Providers, use a local Ollama model, or use an external agent with its own account.

Tool calls are subject to the Agent Panel's normal confirmation flow. `ddev-mcp` also blocks commands it classifies as dangerous (for example destructive Platform.sh or database operations) unless `ALLOW_DANGEROUS_COMMANDS=true` is set in the server's `env` block in `.zed/settings.json`.

If `.zed/settings.json` already exists and has no `#ddev-generated` marker, the add-on leaves it alone and prints a message. Copy the `context_servers` block from `.ddev/zed/settings.json` into your file manually. If you skip the opt-in, `.zed/settings.json` is not created and the Agent Panel is unaffected.

## Ownership

Files containing `#ddev-generated` belong to the add-on and are updated on reinstall. Delete that line to take ownership; the add-on will then skip the file on install and keep it on removal. When it skips a file, it lists the template entries your file doesn't have (task and debug labels, or the `ddev-mcp` server) so you can merge them by hand from `.ddev/zed/`.

## Debugging

1. Start "DDEV: Listen for Xdebug" from the debug panel.
2. Run the `ddev: xdebug toggle` task.
3. Load the page.

The listener binds to `0.0.0.0:9003` so the web container can reach it, and maps `/var/www/html` to `$ZED_WORKTREE_ROOT`, the [task variable](https://zed.dev/docs/tasks#variables) Zed resolves to the project root. If breakpoints don't trigger, see the [FAQ](FAQ.md): the usual causes are a host firewall blocking port 9003 or, rarely, the variable not resolving.

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

## Windows

Tested on Windows 11 with Zed 1.21 and DDEV v1.25.4 (September 2026).

**WSL2 (recommended by DDEV).** Install and run DDEV inside WSL. Open the project from Zed for Windows with "Open Remote" and pick your WSL distro, or run `ddev zed` from the WSL shell: Zed's installer puts a WSL-aware `zed` wrapper on the Windows `PATH`, which WSL interop exposes. Zed asks you to trust the project on first open. What works:

- `ddev zed` and `ddev zed -n`.
- Tasks. They run in a WSL shell, so `ddev` is found without any PATH changes.
- The MCP server (untested on Windows, expected to work since it runs on the WSL side).
- Xdebug, **after one WSL setting**. Out of the box the listener fails with "Connection to TCP DAP timeout", a Zed bug in how it reaches debug adapters inside WSL. Disabling IPv6 in WSL works around it: breakpoints then hit normally. See the [FAQ](FAQ.md#the-debugger-fails-with-connection-to-tcp-dap-timeout-wsl2) for the setting and its trade-off.

**Traditional Windows with Docker Desktop.** DDEV runs the installer and `ddev zed` through Git Bash, so Git for Windows is required. The Xdebug listener starts (verified) and Windows Defender Firewall asks to allow Node.js the first time; click Allow. The installer itself and a full breakpoint round-trip have not been verified on this setup yet.

## FAQ

See [FAQ.md](FAQ.md) for firewall setup, path mapping fallbacks, and merging into user-owned files.

## Remove

```bash
ddev add-on remove zed
```

**Contributed and maintained by [@jfeid](https://github.com/jfeid)**
