# Boomux for Omarchy

A persistent Omarchy side pane for navigating Boomux Workspaces, opening managed
terminals and Agent Sessions, monitoring Agents, and checking Nodes.

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
- Opens a compact contextual Session drawer from the main pane's inward edge,
  at a fixed full width with a dedicated icon on each coordinated Workspace row.
- Browses one coordinated Workspace's Session history from its exact active
  Node placements without loading private host catalogs during tree expansion.
- Shows bounded owner-observed repository/branch contexts without replacing a
  Session's launch directory or fabricating context for catalog-only history,
  including optional latest-Agent attribution, activity age, and bounded no-fetch
  staged, unstaged-or-untracked, and local-ref push status.
- Inspects exact Sessions and, when the owner advertises optional display-name
  support, assigns or resets a Boomux-only name without changing harness history.
- Delegates available Boomux upgrades to the CLI's verified guided updater.
- Confirms available plugin updates in the pane, then delegates fetching,
  validation, rollback, and reload to Omarchy's plugin updater.
- Provides three-dot action menus for Workspaces, items, and Nodes, including
  Shell creation, Shell start-folder changes, rename, guided recovery, and
  confirmed removal actions when supported.
- Creates a generated coordinated Workspace and its first generated Shell from
  `+` or `N`, always on the exact eligible local Node at `$HOME`, without opening
  a terminal.
- Offers a project-folder action when Boomux has configured project roots, using
  each discovered project name and canonical path without an editing form.
- Reserves the left or right screen edge so Hyprland tiles applications beside
  the pane instead of covering them.
- Keeps the main pane's edge reservation stable while the optional Session
  drawer overlays the adjacent desktop area.
- Presents coordinated Workspaces immediately through Boomux's Hyprland desktop
  integration.
- Shows the active Workspace, focused managed terminal, Agent attention, and
  Node health.
- Opens exact Shells, Agents, and eligible Sessions while keeping the pane visible.
- Uses confirmed removal actions for coordinated Workspaces and local Shells or
  launchers.

## Requirements

- Omarchy with shell plugin support.
- Boomux 1.7.0 or newer on `PATH`, advertising `exact_session_open` for Session activation.
- A native terminal supported by `xdg-terminal-exec`.

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
| Session icon on a coordinated Workspace | Open or close its Session rail, presenting that exact Workspace when opening |
| Session card | Single-click the card body to show or hide context; choose the terminal icon or double-click to open the exact eligible Node-qualified Session |
| Hide in a Session menu | Persistently hide it from this Workspace without deleting provider history, Agents, Shells, or processes |
| Launcher row | Invoke the detached launcher; no managed terminal or retained output is created |
| `+` or `N` | Immediately create a generated Workspace and first Shell at `$HOME` |
| Project folder icon | Choose a configured project and create a same-named Workspace and generated Shell at its canonical path |
| Workspace three-dot menu | Browse Sessions for a coordinated Workspace, create a Shell, change its local **Shell Start Folder**, rename, or remove when supported |
| `Tab` / `Shift-Tab` | Move between Workspaces, expanded items, and the lower view |
| Arrow keys or `H` / `J` / `K` / `L` | Move within the focused section; expand or collapse Workspaces |
| `Enter` or `Space` | Activate the focused row or menu action |
| `M` | Open actions for the focused Workspace, item, or Node |
| `1` / `2` | Switch Agents and Nodes |
| Arrow key from Session search | Select a card and transfer keyboard navigation to the rail |
| `Space` or `Right` / `L` in Sessions | Expand the selected Session card |
| `Left` / `H` in Sessions | Collapse the selected Session card |
| Search in Sessions | Filter the loaded Session catalog locally by title, branch, Workspace, harness, attention, lifecycle state, currentness, or Node |
| `Enter` in Sessions | Open the selected eligible Session through `boomux session open` |
| Dismiss Attention in a Session menu | Acknowledge every exact still-matching Agent attention revision projected onto that Session |
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
focus. The Workspace-row Session icon opens its rail passively; **Browse Sessions**
in the action menu opens the rail with keyboard focus.
`Super+A` toggles an explicit keyboard mode, shown by a contrasting
outline, inner-edge wash, and focus rail. Its neutral row cursor uses the same
shade as pointer hover. Because layer-shell drawers are not Hyprland windows,
`Super+Arrow` cannot navigate into the pane; while keyboard mode is active it
exits the mode and returns keys to the window Hyprland selects.
Clicking outside the drawer likewise exits keyboard mode without closing it.

Selecting a coordinated Workspace presents its existing Hyprland layer and
stores it as Boomux's default Workspace. If the layer has no windows, Boomux
opens its existing Shells to populate it; pending or exited Shells can start a
run. This presentation does not invoke launchers.

The pane remains visible while applications receive focus and while other
Omarchy plugins open.

## Sessions

Each coordinated Workspace row has a Session icon that opens or closes its Session
drawer without taking keyboard focus. The drawer slides from the main pane's
inward edge toward the center of the screen and mirrors with the configured pane
side. It follows only the currently Hyprland-presented coordinated Workspace. A Workspace
change keeps the rail open, clears data from the old source identity, defaults
the destination to the new source, and discovers the new exact placements. With
no presented coordinated Workspace, the rail shows an empty prompt and runs no
catalog command.

The row icon and **Browse Sessions** in its action menu first present or open that
Workspace using the normal Workspace semantics, then reveal the rail. Until
Hyprland reports that exact Workspace active, the rail shows a
transition state and does not query the previously active Workspace. Merely
expanding a Workspace never loads Session history. Discovery sends one query for
each exact active eligible `(Node ID, owner Workspace ID)` placement and
keeps `(node_id, session_id)` as the identity, rejects responses for a different
owner Workspace, and retains successful placement results when another placement
fails. Cold and stale rail entry, relevant owner changes, and explicit refresh
start discovery; merely leaving the rail open does not poll host catalogs. An
explicit `R` waits for a fresh Boomux snapshot before reloading Sessions.

Discovery stages every placement separately from the visible catalog. A cold load
shows continuous placement progress without presenting zero as a completed total.
A refresh keeps the prior complete catalog visible and searchable, then replaces
all placement results once after the transaction settles. No title, row, group,
or ordering change is published incrementally.

The header summarizes outstanding attention, active work, and total loaded
Sessions. Cards are grouped as **Needs Attention**, **Active**, **Recent**, and
**History**. Needs Attention uses exact durable blocked or completed Agent
attention; Active requires a current Session occurrence; Recent covers the last
seven days; and History retains everything older, including catalog-only
OpenCode and Codex Sessions with zero Boomux occurrences. History starts
collapsed; group collapse, search, exact selection, and the expanded card are
retained per source Workspace while the pane remains open.

Session totals stay in the rail header rather than Workspace-tree rows. Showing
rollups for every row would require eager private catalog discovery outside the
currently presented Workspace and would make stale partial results look global.

Each collapsed card shows the effective title, override and attention markers,
a compact launch/observation summary, activity age first, lifecycle state, harness, and optional
latest Agent attribution only when it differs from the harness label. Agent-instance
counts remain protocol data rather than pane metadata. Clicking the card body expands a labeled launch branch
and a repository, branch/push-status, and **Seen** table containing up to four
owner-observed contexts. Repository identities are shown verbatim, so a plugin
checkout such as `io.github.gardnmi.boomux` is not confused with the Boomux
repository. The launch root is omitted from
the observed table because launch is already presented separately; another
repository or worktree may still use the same branch name. A `+N more` suffix
uses the owner's total distinct context count and the expanded card offers
**View details**. Exact inspection replaces the list with a detail pane containing
up to 64 owner contexts plus occurrence metadata. Search includes repository and
branch labels, filters the complete loaded catalog locally, and does not query the
daemon or any Node. Pressing an arrow from search transfers navigation to the
cards. `Space` or Right expands the selected card, Left collapses it, and Enter,
the terminal icon, or double-click opens through the source Workspace. The exact
card spins its icon and exposes **Opening Session...** in the tooltip while that
request is active. There is no alternate destination or inferred resume command.
Escape or an outside click releases rail keyboard ownership
back to the main pane; the rail close button controls its visibility. Closing the
main Boomux pane also closes the rail to avoid an orphaned reservation or focus
owner. Done or unavailable Sessions remain visible but cannot be opened.

When the installed CLI and owning Node advertise `session_display_names` plus
the `session.rename` and `session.reset-name` JSON commands, the card menu offers
inline **Rename**. Mutations use the exact Node, Session ID, and owner Workspace
revision. A revision conflict refreshes without retrying the mutation and
restores the draft. A small diamond marks an effective name backed by a Boomux
user override. Older compatible Boomux versions continue to browse and open
Sessions without this action; their additive revision `0` keeps naming controls
unavailable.

When `session_presentation_context` is available, a yellow marker and the Needs
Attention group reflect exact Agent-owned attention references, and branch
context is inspected only by the owning Node. Selecting a card never clears the
marker. Successful Session activation acknowledges the listed revisions after
terminal launch. **Dismiss Attention** performs the same guarded acknowledgment
without opening; a concurrently newer revision remains visible.

When the owner additionally advertises `observed_agent_working_contexts`,
repository/branch rows come from bounded durable observations made by exact
Agent occurrences. They may be incomplete, never fabricate context for
catalog-only history, and do not change the Session's source directory or open
destination. Structured tool paths can legitimately include configuration or
plugin Git checkouts when the Agent reads or edits them. Older protocol-50 owners
continue to show the launch-branch fallback and attention behavior.

Protocol-51 owners may additionally advertise
`session_latest_agent_attribution`, `session_working_context_push_status`, and
`session_working_context_worktree_status`. The owner performs bounded no-fetch
inspection and exposes only exceptional labels: `Unstaged` includes untracked
work, `Staged` marks index changes, `↑N` marks committed-ahead work, and
`Unpublished` marks a branch without an upstream. Clean, up-to-date, and unknown
status add no label. No file names, counts, contents, behind count, or fetched
state are exposed. **Seen** remains the time the Agent observed that Working
Context, not the time Git status was inspected.

When the CLI and exact owning Node advertise `workspace_session_hiding` and the
`session.hide` JSON command, the card menu offers **Hide**. Boomux stores the
preference on that owner Workspace immediately and the plugin refreshes the
exact source catalog. The mutation is not retried after an
unknown outcome, does not hide the same conversation in another Workspace, and
does not delete harness history or any managed process. There is no unhide action.

Activation invokes only `boomux session open SESSION_ID [--node NODE_ID]
[--workspace ACTIVE_WORKSPACE_ID]` as an
exact argv array. Boomux revalidates current ShellRun ownership or historical
resume eligibility and fails closed if the target changed. Historical Sessions
open as managed command-backed Shells in the source Workspace so their
lifecycle integration can register the resumed Agent. Boomux's process adapter
provides an immediate provisional Agent presentation until that authoritative
report arrives. The plugin never
reconstructs harness resume commands or substitutes an ordinary Shell open.

Workspace creation is intentionally local and form-free. Boomux generates both
names and atomically persists the coordinated Workspace, local placement, and
first Shell without opening a terminal. The project-folder action uses the same
command with the discovered project name and canonical path returned by
`project list`. It does not permit name editing, arbitrary path entry, or remote
fallback.

## Settings

Use the gear button to:

- Move the pane to the left or right edge.
- Adjust the main pane width in 20-pixel steps.
- Resize the main pane directly with `Super+right-drag`; the Session drawer stays
  at its full 520-pixel width unless the remaining screen area is narrower.
- Open `boomux config edit` in a native terminal.

The Nodes view lists registered remote Nodes with route, helper and control
versions, protocol, freshness, resource counts, and Workspace eligibility. Its
**Create Shell** action uses the exact selected remote Node and
the currently active Boomux Workspace; paths and commands are resolved on that
Node.

For a coordinated Workspace with one active local placement, **Shell Start
Folder** opens at that placement's current folder or `$HOME`. **Start New Shells
Here** changes where future Shells begin; existing Shells and runs are unchanged.

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

For a current Node that advertises protocol-48 uninstall coordination,
**Uninstall Boomux** is separate from **Forget Node**. **Uninstall Boomux** opens
`boomux node uninstall` with the exact Node ID in a native terminal. Boomux
shows the process, integration, executable, durable-data, configuration, and
registration impact before requiring confirmation. **Just Forget** never
contacts the remote Node, stops no remote processes, and removes only the local
registration and cached projection.

Omarchy stores pane settings in `~/.config/omarchy/shell.json`:

```json
{
  "id": "io.github.gardnmi.boomux",
  "side": "right",
  "paneWidth": 400
}
```

## Tailnet Web

The pane shows **Start Web**, **Open**, and **Stop** when the installed Boomux
supports web management. **Start Web** requires connected Tailscale and runs
`boomux web start --tailscale`, publishing the Boomux dashboard and enabled
OpenCode runtime. Suitable tailnet grants and ACLs are still required.

**Stop** stops only the web gateway and removes routes created by Boomux. It does
not stop the daemon, managed processes, or Shared Harness Runtime. Boomux does
not authenticate the full-control OpenCode service; the private access layer
must provide TLS, authentication, and authorization.

## Safety

- The plugin talks only to the local Boomux CLI; Boomux owns daemon lifecycle,
  remote routing, authentication, and persistence.
- Session lists are cached only in the running Omarchy Shell process so closing
  and reopening the pane can render immediately. A stale source refreshes on
  entry, relevant owner change, or explicit request, but not on a visible timer.
  A failed placement refresh retains its last bounded rows with a warning.
  Requests, process output, and details are cleared on pane close; daemon loss
  clears the cache. Nothing is written to disk or logged.
- Workspace Session discovery uses only active, current, non-stale placements
  and exact owner Workspace IDs. It excludes unavailable and close-pending
  placements and never merges equal Workspace names. In-memory results are
  reused only for the same source identity and exact placement owner revisions.
- Session display-name changes are live owner-routed mutations. They are never
  queued for unavailable Nodes, never retried after a conflict or ambiguous
  outcome, and never modify OpenCode, Codex, Pi, Claude, or Kiro history.
- Session hiding is a live owner-routed, persistent Workspace preference. The
  plugin capability-gates its explicit menu action, never retries an ambiguous write, and
  never treats it as provider-history, Agent, Shell, or process deletion.
- Passive refresh leaves a stopped daemon stopped. Explicit `+`/`N` creation
  starts Boomux when needed, refreshes its protocol and Node snapshot, resolves
  exactly one eligible local Node, and only then builds the atomic command once.
- Workspace creation and Shell start-folder changes use exact argv and returned
  IDs. The pane does not reissue a mutation after completion or an unknown
  outcome, optimistically update the model, or fall back to a remote Node.
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
Boomux behavior should be additive, and replaced capabilities remain available
until supported plugin releases no longer need them. Backend-only fixes do not
require a plugin release when they preserve the declared contract.

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
updates the plugin. If plugin replacement then fails, the existing plugin stays
installed, the pane reports the detected compatibility state, and recovery is:

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
