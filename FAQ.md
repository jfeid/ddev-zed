# FAQ

## Breakpoints never trigger

Xdebug inside the web container connects back to the host on port 9003. Check these in order.

### 1. Host firewall

The most common cause on Linux. Docker containers reach the host through the bridge network, so a host firewall such as `ufw` must accept incoming connections on 9003 from that network. Example:

```bash
sudo ufw allow from 172.16.0.0/12 to any port 9003 proto tcp comment 'xdebug from docker'
```

`172.16.0.0/12` covers Docker's default bridge ranges. Use `docker network inspect ddev_default` to confirm the subnet on your machine, or `sudo ufw allow 9003/tcp` if you don't need to scope it.

On Windows with Docker Desktop, the container connects through `host.docker.internal`. The first time the listener starts, Windows Defender Firewall may prompt to allow Node.js (the debug adapter); allow it on both private and public networks. Whether it prompts depends on the machine: with Docker Desktop's Hyper-V backend, the connection can arrive over loopback, which the firewall doesn't filter. If breakpoints don't hit and the prompt was dismissed or never appeared, add the rule in an elevated PowerShell:

```powershell
New-NetFirewallRule -DisplayName "Xdebug from Docker" -Direction Inbound -Protocol TCP -LocalPort 9003 -Action Allow
```

Under WSL2 the listener runs inside WSL and no Windows firewall rule is needed. If it fails to start there, see the WSL2 timeout entry below.

### 2. Xdebug is off

The add-on's listener does not enable Xdebug for you. Run the `ddev: xdebug toggle` task or `ddev xdebug on`, and confirm with `ddev xdebug status`. Turn it off again when done; it slows every request.

### 3. Listener hostname

`.zed/debug.json` sets `"hostname": "0.0.0.0"` so the adapter listens on all interfaces. Without it, Zed only listens on localhost and the container can't connect. If you took ownership of the file, make sure that line is still there.

### 4. Path mapping

`pathMappings` maps `/var/www/html` (the project root inside the container) to `$ZED_WORKTREE_ROOT`, which Zed resolves to the absolute project root when the debug session starts. This is the [documented approach](https://zed.dev/docs/debugger) and works out of the box.

A few users report the variable failing to resolve inside `pathMappings`, and Zed has open bugs where it is unset or wrong in edge cases: [#22912](https://github.com/zed-industries/zed/issues/22912) when spawning from a buffer outside the worktree, and [#44140](https://github.com/zed-industries/zed/issues/44140) when a file outside the project has focus while the project loads. See also the [Zed + DDEV + Xdebug discussion](https://github.com/zed-industries/zed/discussions/43867).

If you hit this, take ownership of `.zed/debug.json` (delete the `#ddev-generated` line) and replace the variable with the absolute path:

```json
"pathMappings": {
  "/var/www/html": "/home/you/Projects/my-site"
}
```

Remember to update it if you move the project. Restarting Zed also clears the #44140 case.

## The debug picker shows "No matches"

Zed only lists debug configs whose adapter is registered. The Xdebug adapter comes from Zed's PHP extension, so install it (`zed: extensions`, search "PHP") and reopen the picker. The status bar shows "PHP" instead of "Unknown" for `.php` files once it's active.

## Language server phpactor: `env: 'php': No such file or directory`

Harmless for debugging, but noisy. The PHP extension's default language server, phpactor, needs a `php` binary on the machine running Zed (inside WSL, when the project is open through WSL). DDEV projects typically have PHP only in the container. Either switch the project to intelephense, which runs on Node that Zed downloads itself:

```json
{ "languages": { "PHP": { "language_servers": ["intelephense", "!phpactor"] } } }
```

in `.zed/settings.json`, or install PHP on the host (`sudo apt install php-cli`, and `php-mbstring` for phpactor).

## The debugger fails with "Connection to TCP DAP timeout" (WSL2)

Symptom: the project is open through Zed's WSL remote, "DDEV: Listen for Xdebug" shows a red dot, and the console prints `error: Connection to TCP DAP timeout 127.0.0.1:<port>`. Xdebug, DDEV and the firewall are not involved. The failure happens before Zed talks to the adapter at all: Zed's log shows `Debug adapter has connected to TCP server 127.0.0.1:<port>` followed by the timeout, and the DAP log (`debugger: open dap logs`) stays empty. Raising `debugger.timeout` in Zed settings only makes it wait longer.

The likely cause is IPv6. Inside WSL the adapter listens on both IPv4 and IPv6, but WSL's localhost relay only forwards it to Windows over IPv6 (`::1`), while Zed connects to `127.0.0.1`. The Zed issue to follow is [#46137](https://github.com/zed-industries/zed/issues/46137).

**Workaround:** disable IPv6 inside WSL. In PowerShell, open the WSL config file:

```powershell
notepad "$env:USERPROFILE\.wslconfig"
```

Add the following, or add only the second line if a `[wsl2]` section already exists. If a `kernelCommandLine` line exists, append `ipv6.disable=1` to it with a space instead.

```ini
[wsl2]
kernelCommandLine=ipv6.disable=1
```

Save as `.wslconfig` exactly (choose "All Files" in the save dialog so Notepad doesn't add `.txt`), then restart WSL and your project. Make sure no `apt` run is in progress in WSL first: `wsl --shutdown` interrupts it and leaves packages half-configured (`sudo apt --fix-broken install` repairs that).

```powershell
wsl --shutdown
```

```bash
cat /proc/cmdline | grep -o ipv6.disable=1   # confirms the setting
cd ~/path/to/project && ddev start
```

Reopen the project in Zed and start the listener. Verified on Windows 11 with Zed 1.21 and DDEV v1.25.4 (September 2026): the listener connects and breakpoints hit.

This turns IPv6 off for everything in every WSL distro. Nothing in DDEV needs it, but if another tool of yours does, revert by removing the line and running `wsl --shutdown` again.

## Where are the tasks? They're not in the Command Palette

The Command Palette lists actions, not tasks. Open the task picker with `task: spawn` (`alt-shift-t` by default) and type `ddev` to filter. To bind a task to a key, add a `task::Spawn` entry with a `task_name` to your global `keymap.json`; see the README for an example.

## How do I know the MCP server is running?

Open Zed's settings (`agent: open settings` or Settings, then AI, then MCP Servers). `ddev-mcp` should be listed with a green dot. A red dot means the server failed to start, usually because `npx` isn't on the `PATH` Zed sees, or because Node.js is older than 20.

If the server isn't listed at all:

- Zed only reads project-level `context_servers` when a single folder is open. With several folders in the workspace they are ignored ([#51951](https://github.com/zed-industries/zed/issues/51951)). Open the project on its own.
- Reload the workspace after editing `.zed/settings.json`.

## The Agent Panel says "No model selected"

Zed's free plan doesn't ship a model for the built-in agent. Options:

- **Claude Code in Zed.** Click `+` in the Agent Panel and choose "New Claude Code Thread". It signs in with your Anthropic account. Zed forwards `ddev-mcp` to it.
- **Your own API key.** Configure Providers, add an Anthropic, OpenAI, or Google key, then pick a model. Billed per token.
- **Ollama.** Run a local tool-capable model such as `qwen2.5-coder`; Zed detects it automatically.

For the built-in agent, also make sure the active profile has the `ddev-mcp` tools switched on: open the profile selector next to the model picker and configure its MCP tools.

## Is the agent actually using ddev-mcp?

A call through the server shows up in the thread as a tool card named after the tool, for example `ddev_describe` on `ddev-mcp`. Output with no tool card, or a mention of a shell or sandbox, means the agent ran `ddev` itself through its terminal tool instead.

With Claude Code in Zed, `/mcp` in the thread only prints a count of connected servers. To check by name, ask: "List your connected MCP servers and whether you have a tool called ddev_describe." If `ddev-mcp` is missing, start a new thread after the project has fully loaded; Zed can fail to forward servers to a thread created too early ([#64611](https://github.com/zed-industries/zed/issues/64611)).

For projects opened through WSL, Zed doesn't forward `ddev-mcp` to Claude Agent threads, even fresh ones (Windows 11, Zed 1.21). Zed starts the server on the Windows side, while the Claude Agent runs inside WSL. Zed's built-in agent is unaffected. To give Claude Agent the tools, register the server in Claude's own project config, `.mcp.json` in the project root, with the plain `npx` form since the agent runs inside WSL:

```json
{ "mcpServers": { "ddev-mcp": { "command": "npx", "args": ["-y", "ddev-mcp"] } } }
```

Start a new Claude Agent thread and approve the project server when asked. Verified: the thread then calls `ddev_describe` through `ddev-mcp`. If no approval prompt appears and the tools are missing, pre-approve it in `.claude/settings.local.json` with `{ "enabledMcpjsonServers": ["ddev-mcp"] }`.

Claude Code has its own shell and may prefer it over the MCP tools. Asking it to "use the ddev-mcp tools instead of the shell" works. One advantage of the server there: it runs outside Claude Code's command sandbox, so it doesn't need a sandbox bypass to reach the Docker socket.

## ddev-mcp shows "Context server request timeout" (Windows)

Zed reports any server that doesn't answer within 60 seconds this way, including one that crashed on start. On Windows the add-on writes an entry adapted to your setup; a plain `npx -y ddev-mcp` entry with no `env` means it was installed elsewhere or the file predates that. Re-run `DDEV_ZED_MCP=true ddev add-on get jfeid/ddev-zed` (in PowerShell: `$env:DDEV_ZED_MCP = "true"` first) from the same environment you run DDEV in. Causes seen in testing:

- **WSL:** Zed for Windows starts MCP servers on Windows even when the project is open through WSL, so `npx` isn't found. The WSL entry uses `wsl.exe` instead. Also check that `npx` exists inside WSL: on Ubuntu, `sudo apt install nodejs npm`.
- **Traditional Windows:** `ddev-mcp` reads the project folder from the `PWD` environment variable and, when it's missing, calls the Unix `pwd` command, which `cmd.exe` doesn't have, and exits. Zed started from the Start menu has no `PWD`; started with `ddev zed` it inherits one from Git Bash, which is why the problem can seem to come and go. The Windows entry sets `PWD` to the project root.

## The add-on skipped one of my files

Any file in `.zed/` without the `#ddev-generated` marker is yours. The add-on won't overwrite or remove it. The canonical templates are always in `.ddev/zed/`; open the matching file there and copy the entries you want into your own file.

The skip message tells you what's missing, for example:

```
Skipped .zed/tasks.json: it exists and is user-owned. Merge manually from .ddev/zed/tasks.json
  Not found in your .zed/tasks.json: "ddev: snapshot", "ddev: xdebug diagnose"
```

The check is a plain text search for each template label, so a task you renamed will show up as missing. The add-on never writes into a user-owned file, even additively: Zed's files are JSONC with comments, and there is no portable way to merge into them without losing those comments or breaking `ddev add-on remove`.

To hand a file back to the add-on, delete it and re-run `ddev add-on get jfeid/ddev-zed`.

## `ddev zed` says the CLI is not found

The command looks for `zed`, then `zeditor` (some Linux distro packages), then `zed.exe` (Windows CLI from inside WSL), then the Flatpak. Fixes by platform:

- **Linux, macOS:** run `zed: install cli` from Zed's command palette, which links the CLI into `~/.local/bin` or `/usr/local/bin`.
- **WSL2:** Zed's Windows installer offers to add `%LOCALAPPDATA%\Programs\Zed\bin` to the user `PATH` (checked by default). That directory holds both `zed.exe` and a WSL-aware `zed` shell wrapper, and WSL interop exposes both, so `which zed` in the WSL shell should print a `/mnt/c/...` path. If it prints nothing, the box was unchecked: add the directory to the Windows user `PATH` and open a new WSL shell.
- **Traditional Windows:** the command runs in Git Bash, which resolves `zed` to `zed.exe` when it's on `PATH`.

## I moved or renamed the project

Nothing to do. `$ZED_WORKTREE_ROOT` follows the project. Only a hardcoded absolute path (see above) needs updating.
