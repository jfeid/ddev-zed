# FAQ

## Breakpoints never trigger

Xdebug inside the web container connects back to the host on port 9003. Check these in order.

### 1. Host firewall

The most common cause on Linux. Docker containers reach the host through the bridge network, so a host firewall such as `ufw` must accept incoming connections on 9003 from that network. Example:

```bash
sudo ufw allow from 172.16.0.0/12 to any port 9003 proto tcp comment 'xdebug from docker'
```

`172.16.0.0/12` covers Docker's default bridge ranges. Use `docker network inspect ddev_default` to confirm the subnet on your machine, or `sudo ufw allow 9003/tcp` if you don't need to scope it.

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

## The add-on skipped one of my files

Any file in `.zed/` without the `#ddev-generated` marker is yours. The add-on won't overwrite or remove it. The canonical templates are always in `.ddev/zed/`; open the matching file there and copy the entries you want into your own file.

The skip message tells you what's missing, for example:

```
Skipped .zed/tasks.json: it exists and is user-owned. Merge manually from .ddev/zed/tasks.json
  Not found in your .zed/tasks.json: "ddev: snapshot", "ddev: xdebug diagnose"
```

The check is a plain text search for each template label, so a task you renamed will show up as missing. The add-on never writes into a user-owned file, even additively: Zed's files are JSONC with comments, and there is no portable way to merge into them without losing those comments or breaking `ddev add-on remove`.

To hand a file back to the add-on, delete it and re-run `ddev add-on get maxwebgr/ddev-zed`.

## I moved or renamed the project

Nothing to do. `$ZED_WORKTREE_ROOT` follows the project. Only a hardcoded absolute path (see above) needs updating.
