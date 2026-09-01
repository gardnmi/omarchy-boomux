# Boomux for Omarchy

A persistent Omarchy side pane for navigating Boomux Workspaces, opening managed
terminals, monitoring Agents, and checking Nodes.

> [!IMPORTANT]
> This plugin does not work without [Boomux](https://github.com/gardnmi/boomux).
> Install Boomux first and ensure `boomux` is available on `PATH`.

<p align="center">
  <img src="assets/boomux-workspace-desktop.png" width="100%" alt="Boomux persistent side pane beside an active tiled Workspace">
</p>

## Highlights

- Keeps an expandable multi-Workspace tree visible above Agent and Node views.
- Shows the installed Boomux CLI version in the pane header.
- Lists current Agents and outstanding blocked or completed attention by latest
  authoritative update.
- Delegates available Boomux upgrades to the CLI's verified guided updater.
- Confirms available plugin updates in the pane, then delegates fetching,
  validation, rollback, and reload to Omarchy's plugin updater.
- Provides three-dot action menus for Workspaces, items, and Nodes, including
  Shell creation, rename, guided recovery, and confirmed removal actions when
  supported.
- Creates a generated coordinated Workspace and its first generated Shell from
  `+` or `N`, always on the exact eligible local Node at `$HOME`, without opening
  a terminal.
- Offers a project-folder action when Boomux has configured project roots, using
  each discovered project name and canonical path without an editing form.
- Reserves the left or right screen edge so Hyprland tiles applications beside
  the pane instead of covering them.
- Presents coordinated Workspaces immediately through Boomux's Hyprland desktop
  integration.
- Shows the active Workspace, focused managed terminal, Agent attention, and
  Node health.
- Opens exact Shells and Agents while keeping the pane visible.
- Uses confirmed removal actions for coordinated Workspaces and local Shells or
  launchers.

## Requirements

- A current Omarchy release with Shell bar-plugin, IPC, and inline-settings
  support.
- Boomux 1.7.0 or newer on `PATH`.
- Omarchy's `omarchy-launch-tui` with a working native terminal configuration.
- `xdg-terminal-exec` and an available terminal desktop entry for Shell and
  Agent opens through Boomux.

[`compatibility.json`](compatibility.json) is the machine-readable source of
truth for the required CLI schema, minimum daemon protocol, capabilities, and
diagnostic minimum Boomux release. The pane validates the installed CLI before
starting passive daemon polling. An unsupported installation shows an update
path instead of sending requests that the backend cannot handle.

## Install

After installing Boomux, the recommended setup offers to install and enable the
plugin, configure integrations and the Agent Skill, and add managed keybindings:

```console
boomux setup
```

To install only the pane, review it first because Omarchy plugins run as
unsandboxed shell-process code, then run:

```console
omarchy plugin add https://github.com/gardnmi/omarchy-boomux.git --enable
```

The widget defaults to the right bar section and opens a pane from the left edge.
Omarchy's graphical environment must be able to resolve `boomux`; official Boomux
releases install it to `~/.local/bin`.

## Use

| Input | Action |
| --- | --- |
| Bar icon | Open or close the main pane |
| Right-click bar icon | Refresh |
| `Super+B` with the bindings below | Open or close the passive main pane |
| `Super+A` with the bindings below | Enter or leave Boomux keyboard mode |
| `Super+Arrow` in keyboard mode | Return keyboard ownership to Hyprland |
| Coordinated Workspace row | Present that Workspace; if its layer has no windows, open its existing Shells to populate it without invoking launchers |
| External or legacy Workspace row | Open or restore that Workspace; exited Shells may restart and launchers may run |
| Workspace chevron | Expand Shells, commands, and launchers |
| Shell, command, or Agent row | Open the exact Shell with takeover, disconnecting its current writable controller; an exited Shell starts a new run, and opening an Agent acknowledges its current attention through its owner |
| Launcher row | Invoke the detached launcher; no managed terminal or retained output is created |
| `+` or `N` | Immediately create a generated Workspace and first Shell at `$HOME` |
| Project folder icon | Choose a configured project and create a same-named Workspace and generated Shell at its canonical path |
| Workspace three-dot menu | Create a Shell, rename, or remove when supported |
| `Tab` / `Shift-Tab` | Move between Workspaces, expanded items, and the lower view |
| Arrow keys or `H` / `J` / `K` / `L` | Move within the focused section; expand or collapse Workspaces |
| `Enter` or `Space` | Activate the focused row or menu action |
| `M` | Open actions for the focused Workspace, item, or Node |
| `1` / `2` | Switch Agents and Nodes |
| `A` in Nodes | Open guided Node setup |
| Create Shell in Nodes | Create and open a Shell in the active Workspace on that remote Node |
| Authenticate in Nodes | Open interactive authentication for an existing registered Node |
| Update in Nodes | Reconnect, verify, and update an older remote Boomux helper in a native terminal |
| Uninstall Boomux | Choose **Uninstall Boomux**, confirm **Uninstall**, then review the exact remote process and data impact in Boomux's terminal workflow |
| Forget Node | Confirm **Just Forget** to remove only the local registration without contacting the remote Node |
| `D` in Agents | Dismiss the selected Agent notification through its current owner when available |
| `R` | Refresh |
| `Escape` | Dismiss the current menu, form, picker, dialog, or settings view; otherwise close the pane |

For direct keyboard access:

```lua
hl.unbind("SUPER + B")
o.bind("SUPER + B", "Toggle Boomux panel",
  "omarchy-shell io.github.gardnmi.boomux toggle")
o.bind("SUPER + A", "Toggle Boomux panel focus",
  "omarchy-shell io.github.gardnmi.boomux focus")

hl.unbind("SUPER + mouse:273")
o.bind("SUPER + mouse:273", "Resize window or Boomux panel",
  hl.dsp.window.resize(), { mouse = true, non_consuming = true })
o.bind("SUPER + mouse:273", nil,
  hl.dsp.global("quickshell:boomux-pane-resize"), { non_consuming = true })

local function focus_away_from_boomux(direction)
  return function()
    hl.exec_cmd("omarchy-shell io.github.gardnmi.boomux releaseFocus")
    hl.dispatch(hl.dsp.focus({ direction = direction }))
  end
end

hl.unbind("SUPER + LEFT")
hl.unbind("SUPER + RIGHT")
hl.unbind("SUPER + UP")
hl.unbind("SUPER + DOWN")
o.bind("SUPER + LEFT", "Focus on left window", focus_away_from_boomux("l"))
o.bind("SUPER + RIGHT", "Focus on right window", focus_away_from_boomux("r"))
o.bind("SUPER + UP", "Focus on above window", focus_away_from_boomux("u"))
o.bind("SUPER + DOWN", "Focus on below window", focus_away_from_boomux("d"))
```

The main pane is passive when opened with `Super+B`, so applications keep keyboard
focus. `Super+A` toggles an explicit keyboard mode, shown by a contrasting
outline, inner-edge wash, and focus rail. Its neutral row cursor uses the same
shade as pointer hover. Because layer-shell drawers are not Hyprland windows,
`Super+Arrow` cannot navigate into the pane; while keyboard mode is active it
exits the mode and returns keys to the window Hyprland selects.
Clicking outside the drawer likewise exits keyboard mode without closing it.

Selecting a coordinated Workspace presents its existing Hyprland layer and
stores it as Boomux's selected CLI Workspace. If the layer has no windows, Boomux
opens its existing Shells to populate it; pending or exited Shells can start a
run. This presentation does not invoke launchers.

The pane remains visible while applications receive focus and while other
Omarchy plugins open.

Workspace creation is intentionally local and form-free. Boomux generates both
names and atomically persists the coordinated Workspace, local placement, and
first Shell without opening a terminal. The project-folder action uses the same
command with the discovered project name and canonical path returned by
`boomux project list --json`. It does not permit name editing, arbitrary path
entry, or remote fallback.

## Settings

Use the gear button to:

- Move the pane to the left or right edge.
- Adjust the main pane width in 20-pixel steps.
- Resize the main pane directly with `Super+right-drag`.
- Open `boomux config edit` in a native terminal.

The Nodes view lists registered remote Nodes with route, helper and control
versions, protocol, freshness, resource counts, and Workspace eligibility. Its
**Create Shell** action uses the exact selected remote Node and
the currently active Boomux Workspace; paths and commands are resolved on that
Node.

When a Node reports **authentication required**, **Authenticate** opens Boomux's
interactive reauthentication flow in a native terminal. It uses the exact stored
route and pinned identity, requires an existing compatible helper, and does not
install, upgrade, restart, retarget, or rewrite the registration. The action is
shown only with daemon protocol 38 or newer when the installed Boomux advertises
`node_reauthentication`. Before requesting an observer retry, Boomux verifies a
separate prompt-free reconnect after the interactive authentication completes;
the observer reports the resulting Node health asynchronously.

When a remote helper is older than the control machine, **Update** opens Boomux's
guided upgrade in a native terminal. Boomux handles authentication, confirmation,
identity verification, transactional upload, and graceful remote daemon restart.
A newer remote is never downgraded; the pane instead reports **Control machine
update needed**. Cached transient states remain visible and the guided flow
revalidates the exact Node live before changing it.

For an online, non-stale registered Node using protocol 48 or newer, the action
is available when both the installed CLI and Node advertise
`node_uninstall_coordination`. **Uninstall Boomux** is separate from **Forget
Node** and opens `boomux node uninstall` with the exact Node ID in a native
terminal. Boomux explains that managed processes, current integration assets,
and the remote executable are removed while durable state and configuration are
preserved, then requires confirmation. **Just Forget** never contacts the remote
Node, stops no remote processes, and removes only the local registration and
cached projection.

Omarchy stores pane settings in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.gardnmi.boomux",
  "side": "right",
  "paneWidth": 400
}
```

## Tailnet Web

The pane shows **Start Web**, **Open Web**, and **Stop** when the installed Boomux
supports web management. **Start Web** requires connected Tailscale and invokes
`boomux web start --tailscale --json`, publishing the Boomux dashboard and any
active OpenCode Shared Harness Runtime. Suitable tailnet grants and ACLs are
still required.

**Stop** stops only the web gateway and removes routes created by Boomux. It does
not stop the daemon, managed processes, or Shared Harness Runtime. Boomux does
not proxy or authenticate the full-control OpenCode service. Set
`OPENCODE_SERVER_PASSWORD` unless tailnet policy is intended to provide the
authentication boundary; suitable TLS and authorization policy remain required.

## Safety

- For Boomux management, the plugin talks only to the local Boomux CLI; Boomux
  owns daemon lifecycle, remote routing, authentication, and persistence. The
  pane separately uses Omarchy and Hyprland helpers plus bounded HTTPS release
  checks for presentation and update discovery.
- Passive refresh leaves a stopped daemon stopped. The offline pane presents an
  explicit **Start Boomux** action and refreshes automatically after startup.
  Explicit `+`/`N` creation can also start Boomux when needed, refresh its
  protocol and Node snapshot, resolve exactly one eligible local Node, and only
  then build the atomic command once.
- Workspace creation uses exact argv and returned IDs. The pane does not reissue
  a mutation after completion or an unknown outcome, optimistically update the
  model, or fall back to a remote Node.
- Every creation intent performs a fresh daemon status check and fresh Node
  snapshot before constructing argv. After a successful mutation, snapshot
  confirmation is bounded; a timeout reports that the operation completed but
  remains unconfirmed and asks for a refresh without replaying it.
- Remote cached resources stay visible but owner-dependent actions become
  non-actionable when stale or unavailable. Guided update and authentication
  reconnect and verify the registered Node; **Forget Node** remains local
  registration maintenance and does not contact the owner.
- Destructive actions require confirmation and use exact resource IDs. Remote
  uninstall requires a second interactive confirmation from Boomux.
- Removing a coordinated Workspace can terminate Shells and remove launchers,
  retained state, Agent records, and attention across its placements.
  Unavailable placements can leave it visibly closing for retry.
- Opening a Shell or Agent uses takeover and can disconnect another writable
  controller. Opening an exited Shell starts a new run.
- Closing a Shell can terminate its process and delete retained terminal state.
  Removing a launcher does not stop applications it already started.
- The plugin never reads credentials, attachment environments, or remote terminal
  content.
- The plugin never invokes SSH itself. Guided Node setup, updates, and uninstall
  run through Boomux in a native terminal so authentication and confirmation
  stay interactive. Omarchy presents these plugin-owned terminal dialogs as
  centered floating windows.
- New Boomux versions own release discovery through `boomux update status`; the
  pane opens Boomux's interactive `boomux update` workflow. For eligible official
  installations, that workflow verifies, confirms, downloads, and replaces the
  release; package-managed installations are directed to their package manager.
  The pane performs no replacement itself and checks status afterward. Plugin
  update discovery uses the fixed published manifest URL. After one explicit
  pane confirmation, plugin replacement delegates to `omarchy plugin update`
  without a second diff-and-confirmation prompt; Omarchy still validates the
  result, rolls back validation failures, and reloads plugins.

## Maintenance

Update:

```console
omarchy plugin update io.github.gardnmi.boomux
```

Remove:

```console
omarchy plugin remove io.github.gardnmi.boomux
```

Removing the plugin does not remove Boomux, stop managed processes, or delete
Boomux data.

### Compatibility And Releases

Boomux and this plugin release independently. Matching version numbers are not
required: compatibility is determined by the stable CLI schema, negotiated
daemon protocol, and advertised capabilities in `compatibility.json`.

Backend changes are released before the plugin begins to require them. New
required behavior should be additive; removing a capability requires a
compatible plugin release first. Backend-only fixes do not require a plugin
release when they preserve the declared contract.

CI tests the plugin against the oldest declared Boomux release and the current
stable release. A daily compatibility run detects new backend releases even
without cross-repository credentials. The workflow also accepts a
`boomux-release` repository dispatch, and Boomux can call the pinned reusable
compatibility workflow directly after publishing a release without a shared
credential.

Every plugin release has a `v<manifest version>` Git tag and GitHub release for
the exact commit that passed `main` CI. Normal Omarchy updates still follow the
release-ready default branch; tags provide an audit and rollback point.

Guided updates are backend-first: Boomux is updated and verified before Omarchy
updates the plugin. A failed or timed-out plugin update has an unknown outcome
because Omarchy may already have changed the checkout. Reopen or refresh the pane
to inspect its compatibility state; the explicit recovery commands are:

```console
boomux update
omarchy plugin update io.github.gardnmi.boomux
```

If the pane appears stale, right-click the bar icon or press `R`. For CLI issues:

```console
boomux doctor
boomux capabilities --json
boomux daemon status --json
```

## Development

Deploy the complete local plugin and restart Quickshell:

```console
mise run restart
```

Validate changes:

```console
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml SidePane.qml
xmllint --noout assets/bomb.svg assets/bomb-spark.svg
bash -n deploy-local.sh
bun test tests
bun scripts/validate-release.js
bash scripts/test-boomux-releases.sh
git diff --check
```

## License

Code is licensed under the [MIT License](LICENSE). The bomb icon is adapted from
[Font Awesome Free](https://fontawesome.com/icons/bomb) under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
