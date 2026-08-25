# Boomux for Omarchy

A persistent Omarchy side pane for navigating Boomux Workspaces, opening managed
terminals, monitoring Agents, and checking Schedules and Nodes.

> [!IMPORTANT]
> This plugin does not work without [Boomux](https://github.com/gardnmi/boomux).
> Install Boomux first and ensure `boomux` is available on `PATH`.

<p align="center">
  <img src="assets/boomux-workspace-desktop.png" width="100%" alt="Boomux persistent side pane beside an active tiled Workspace">
</p>

## Highlights

- Keeps an expandable multi-Workspace tree visible above Agent, Schedule, and
  Node views.
- Provides three-dot action menus for Workspaces, items, and Nodes, including
  creation, rename, guided recovery, and confirmed removal actions when supported.
- Reserves the left or right screen edge so Hyprland tiles applications beside
  the pane instead of covering them.
- Presents coordinated Workspaces immediately through Boomux's Hyprland desktop
  integration.
- Shows the active Workspace, focused managed terminal, Agent attention, Node
  health, and scheduler state.
- Opens exact Shells and Agents while keeping the pane visible.
- Uses compact, confirmed removal actions for local Workspaces, Shells, and
  launchers.

## Requirements

- Omarchy with the Quattro shell plugin system.
- [Boomux](https://github.com/gardnmi/boomux) `0.27.0` or newer on `PATH`.
- A native terminal supported by `xdg-terminal-exec`.

Global multi-Node Workspaces require Boomux protocol 38. Agent status requires a
supported lifecycle integration:

```console
boomux integration list
boomux integration setup <name>
```

## Install

Omarchy plugins run as unsandboxed code inside the shell process. Review the
source, then install and enable it:

```console
omarchy plugin add https://github.com/gardnmi/omarchy-boomux.git --enable
```

The widget defaults to the right bar section and opens a pane from the left edge.

## Use

| Input | Action |
| --- | --- |
| Bar icon | Open or close the pane |
| Right-click bar icon | Refresh |
| Workspace row | Select and present that Workspace |
| Workspace chevron | Expand Shells, commands, and launchers |
| Shell, command, or Agent row | Open the exact managed terminal |
| Trash icon | Confirm removal of the local resource |
| `Tab` or `1` / `2` / `3` | Switch Agents, Schedules, and Nodes |
| `A` in Nodes | Open guided Node setup |
| Create Shell in Nodes | Create and open a Shell in the active Workspace on that remote Node |
| Authenticate in Nodes | Open interactive authentication for an existing registered Node |
| Update in Nodes | Reconnect, verify, and update an older remote Boomux helper in a native terminal |
| Trash icon in Nodes | Confirm removal of the local Node registration without contacting the remote Node |
| `D` in Agents | Dismiss the selected notification |
| `N` | Create a Workspace |
| `R` | Refresh |
| `Escape` | Close the pane |

For direct keyboard access:

```lua
hl.unbind("SUPER + B")
o.bind("SUPER + B", "Toggle Boomux panel",
  "omarchy-shell io.github.gardnmi.boomux toggle")
```

Selecting a coordinated Workspace presents its existing Hyprland layer and
stores it as Boomux's default Workspace. It does not restore every Shell or run
launchers. Older compatible Boomux versions fall back to `workspace open --show`.

The terminal button opens the full Boomux TUI. The pane remains visible while
applications receive focus and while other Omarchy plugins open.

## Settings

Use the gear button to:

- Move the pane to the left or right edge.
- Adjust its width in 20-pixel steps.
- Open `boomux config edit` in a native terminal.

The Nodes view lists registered remote Nodes with route, helper and control
versions, protocol, freshness, scheduler state, resource counts, and Workspace
eligibility. Its **Create Shell** action uses the exact selected remote Node and
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

Omarchy stores pane settings in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.gardnmi.boomux",
  "side": "right",
  "paneWidth": 400
}
```

## Safety

- The plugin talks only to the local Boomux CLI; Boomux owns daemon lifecycle,
  remote routing, authentication, and persistence.
- Remote cached resources stay visible but become non-actionable when stale or
  unavailable. The guided Node update is the only stale-row exception because
  Boomux reconnects and verifies the exact registered Node before replacement.
- Destructive local actions require confirmation and use exact resource IDs.
- Removing a Shell can terminate its process and delete retained terminal state.
  Removing a launcher does not stop applications it already started.
- The plugin never reads Schedule prompts, credentials, attachment environments,
  or remote terminal content.
- The plugin never invokes SSH itself. Guided Node setup and updates run through
  Boomux in a native terminal so authentication and confirmation stay interactive.
- Its only direct network activity is a bounded update check against fixed GitHub
  release and manifest URLs.

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
bun test tests/workspace-model.test.js
git diff --check
```

## License

Code is licensed under the [MIT License](LICENSE). The bomb icon is adapted from
[Font Awesome Free](https://fontawesome.com/icons/bomb) under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
