# Boomux for Omarchy

Navigate coordinator-owned global Workspaces, monitor interactive Boomux Agents,
and operate recurring Agent Schedules from a full-height Omarchy side pane.

![Boomux Agent status in the Omarchy bar](assets/agents.png)

## Features

- Keeps active Agents in a dedicated status tab
- Slides out from the left or right screen edge, with a configurable width
- Reserves its open screen edge so Hyprland reflows tiled windows beside it
- Keeps an expandable Workspace tree visible above the Agent, Schedule, and Node tabs
- Highlights the Boomux special Workspace currently presented by Hyprland
- Starts, opens, and stops Boomux Web with explicit Tailscale Serve exposure
- Excludes schedule-owned Agents handled by Boomux scheduling
- Shows live `working`, `idle`, and `blocked` Agent states
- Sorts Agents by their latest authoritative update and shows compact relative
  times such as `5m ago`
- Highlights finished work and blocked attention in the bar
- Shows the active Boomux special Workspace name persistently beside the bomb
- Opens the Workspaces panel on the exact Workspace when its persistent
  Workspace or Shell identity label is clicked
- Shows the active Boomux Shell name and its Workspace affiliation, including
  when its terminal window has been moved outside the Boomux Workspace layer
- Keeps finished markers visible until you open the corresponding Agent
- Groups Shells, Agents, launchers, and Schedules by global Workspace task
- Projects resources from multiple Node placements into one Workspace item list
- Opens complete workspaces or individual managed items
- Opens Agent and Shell terminals directly in their owning Boomux Workspace
  layer when the CLI advertises coordinated desktop placement
- Restores every Workspace item and reveals its desktop layer from the
  Workspaces panel's **Open** action
- Makes the explicitly selected coordinated Workspace the default for later CLI creation
- Shows a transient Workspace and Shell notice when focus follows the pointer
  into a managed terminal
- Removes locally owned workspace items after confirming their specific impact
- Creates Workspaces from an existing project or a new name and directory
- Opens an in-panel directory picker for Workspace, Shell, and Agent directories
- Prefills editable shell and Agent names from Boomux suggestions
- Discovers available integrated Agent hosts on the selected Node and starts the
  selected host with its exact advertised executable
- Acknowledges local durable attention when you open its Agent
- Lists Schedules across workspaces with scheduler status and their latest run
- Runs Schedules immediately and pauses or resumes future timed dispatch
- Launches the full Boomux TUI in a new native terminal
- Supports mouse and keyboard navigation and follows the active Omarchy theme
- Polls local Boomux state once per second for responsive updates
- Keeps Node ownership as secondary metadata instead of a Node filter or Node-first label
- Keeps cached stale resources visible but disables owner-dependent actions
- Keeps equal-name unlinked Node-local Workspaces as distinct external Workspaces
- Shows scheduler health independently per Node and disables owner-dependent
  actions while its state is stale or unavailable
- Lists every Node in a dedicated health table with protocol,
  freshness, eligibility, and exact identity details
- Opens interactive **Create Node** setup only in a local native terminal

![Boomux workspace management in the Omarchy bar](assets/workspaces.png)

![Boomux Schedule management in the Omarchy bar](assets/schedules.png)

![Boomux Node health table](assets/nodes.png)

## Requirements

- Omarchy with the Quattro shell plugin system
- [Boomux](https://github.com/gardnmi/boomux) `0.27.0` or newer available on
  `PATH`
- The active-Workspace bar label requires a Boomux build advertising
  `hyprland_special_workspaces` with `[desktop] workspace_layer = "hyprland-special"`
- A configured native terminal supported by `xdg-terminal-exec`
- `curl` for optional passive update detection

Full global Workspace support requires Boomux protocol 38. Protocol 33 through
37 retain the qualified owner-local fallback described below.

Workspace management works with Boomux alone. Agent states and Agent creation
require a coding-agent executable and its current Boomux lifecycle integration.
List the supported hosts and configure one with:

```bash
boomux integration list
boomux integration setup <name>
```

The Agent form queries `boomux integration status --json` on the selected Node
and lists only hosts whose executable is available and whose Boomux lifecycle
asset is current. The available catalog can include OpenCode, Pi, Claude Code,
Codex, Kiro CLI, and later hosts advertised by Boomux without a plugin update.

The plugin does not automatically start a stopped Boomux daemon. Launch Boomux
or open a managed workspace before using the panel.

The Agents-tab Web controls require a Boomux CLI that advertises `web.start`,
`web.status`, and `web.stop`. Older compatible Boomux versions hide these
controls. **Serve Web via Tailscale** requires a connected Tailscale installation
with MagicDNS; Boomux owns conflict detection and exact Serve-route cleanup.

When the `boomux` executable is unavailable on `PATH`, the panel shows a
dedicated installation message, the repository URL, and an **Open Install Page**
button. It does not install Boomux automatically.

Global Workspace grouping activates only when the local CLI advertises the
protocol 38 global Workspace and multi-placement capabilities and the running
local daemon can negotiate them. Protocol 33 through 37 retain qualified
owner-local Workspace rows; older Boomux daemons retain the local-only panel.

Follow the setup command's restart and verification guidance. See the
[Boomux installation instructions](https://github.com/gardnmi/boomux#install)
if `boomux` is not installed yet.

## Install

Review the source before installing. Omarchy plugins run as unsandboxed code
inside the long-running shell process.

```bash
omarchy plugin add https://github.com/gardnmi/omarchy-boomux.git --enable
```

The widget defaults to the right bar section. If you installed it without
`--enable`, enable it later with:

```bash
omarchy plugin enable io.github.gardnmi.boomux --section right
```

The pane itself opens from the left edge by default. Use the in-pane **Settings**
button to change its edge and width. Omarchy persists those inline plugin
settings in `~/.config/omarchy/shell.json`; the equivalent entry is:

```json
{
  "id": "io.github.gardnmi.boomux",
  "side": "right",
  "paneWidth": 400
}
```

`side` accepts `left` or `right`. `paneWidth` is clamped to a usable range.
While the pane is open, its output's usable area excludes the pane width; tiled
windows reflow into the remaining space. Clicking those windows transfers focus
without closing the pane. Opening another Omarchy plugin leaves the Boomux pane
and its reservation in place; ordinary plugin popouts continue using Omarchy's
single-popout behavior among themselves. Closing Boomux explicitly releases its
reservation.

## Use

| Input | Action |
| --- | --- |
| Left click | Open or close the panel |
| Right click | Refresh immediately |
| **Settings** button | Configure the pane or open the active Boomux config in a terminal |
| Workspace row | Select and immediately reveal that Workspace's existing desktop layer while keeping the pane open |
| Workspace chevron | Expand or collapse its Shells, commands, and launchers without opening it |
| Agent, Shell, or command row | Open that terminal while keeping the pane open |
| Tab or `1` / `2` / `3` | Switch the lower section between Agents, Schedules, and Nodes |
| `A` | From Nodes, open interactive Create Node in a native terminal |
| Up / Down | Move selection in the active lower Agents, Schedules, or Nodes section |
| Enter | Open the selected Agent or select the highlighted Schedule |
| `D` | Dismiss the selected Agent notification |
| `N` | Create a workspace |
| `R` | Refresh immediately |
| Escape | Close the panel |

For direct keyboard access, bind `Super+B` to the plugin panel. Pressing it
again closes the pane; Boomux special Workspaces are opened only after choosing
a Workspace row:

```lua
hl.unbind("SUPER + B")
o.bind("SUPER + B", "Toggle Boomux panel",
  "omarchy-shell io.github.gardnmi.boomux toggle")
```

The Settings button opens an in-pane view for moving the pane between the left
and right screen edges and adjusting its width in 20-pixel steps. Changes mutate
the plugin's Omarchy entry through the inline settings API. **Open Boomux config** launches
`boomux config edit` in a native terminal so Boomux resolves the active writable
configuration layer itself.

Clicking a coordinated Workspace row presents its desktop layer and stores its
exact ID as Boomux's local CLI default without restoring every Shell or invoking
launchers. Expanding the row does not change the default or open anything. The
pane remains open over the revealed special Workspace until you close it. Older
Boomux CLIs fall back to full Workspace restore and report completion or partial
failure in the lower-corner notice. Clicking an external owner Workspace clears the coordinated
default so later commands cannot silently target the previous Workspace. Boomux
resolves explicit Workspace arguments before this selection.

Manage the same selection directly:

```console
# Select a Workspace
boomux workspace select <NAME_OR_ID>

# Show the selected Workspace
boomux workspace current

# Clear the selection
boomux workspace clear
```

After selecting, omit the Workspace from context-required commands:

```console
boomux shell create --name dev --cwd .
boomux shell suggest-name
boomux launcher list
boomux schedule create ...
```

An explicitly supplied Workspace still overrides the selection:

```console
boomux shell create other-workspace --name dev --cwd .
```

To create a randomly named Shell in the selected Workspace and immediately open
that exact Shell in a native terminal, bind `Ctrl+Super+Enter` to:

```lua
hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "New Boomux Shell", "boomux shell create --open")
```

The terminal icon in the pane header launches the Boomux dashboard in a new
native terminal window. The Nodes tab keeps **Create Node** at section scope and opens Boomux's
guided Node setup in a local native terminal, where Boomux alone handles SSH
authentication, remote install details, and confirmation. The terminal remains
open after setup so its success or failure is visible. The Node table keeps the
full health state visible and marks stale projections as cached. Selecting a
Node shows its exact ID, observed protocol and time, resource counts, and
Workspace-owner eligibility. It does not display SSH routes or turn
Nodes into a Workspace filter. The upper Workspace tree remains visible while
the lower section switches between Agents, Schedules, and Nodes. Its chevrons
show Shells, commands, and launchers inline; clicking one opens that exact
terminal or invokes that detached launcher. The exact Shell or command whose
managed window currently has Hyprland focus gets a subtle accent dot and tint;
launchers are never marked as focused. Local Shell and command rows also expose
a confirmed **Close** action that terminates the process and removes the Shell
definition and retained terminal state. Local launchers expose confirmed
**Remove**, and the expanded Workspace exposes **Shell**, **Agent**, and
**Remove** actions. Expanding with the chevron positions
that Workspace header at the top of the tree so its visible children remain
above the lower-section tabs. Selecting and opening a Workspace preserves the
current tree viewport. Workspace rows remain selectable while an earlier open
is finishing; the most recently selected Workspace opens next. Drag the thin divider
above the tabs up or down to resize the Workspace tree and lower section; both
surfaces retain a usable minimum height. Polling refreshes preserve the current
Workspace-tree scroll offset instead of jumping back to the first row. Pointer
focus only updates the subtle focused-item indicator; it never expands or scrolls
the Workspace tree. Clicking an Agent in the lower
section opens its managed terminal without dismissing the pane. Opening a managed terminal
takes over its writable controller so the new window receives the authoritative
terminal size and input stream. When Hyprland focus follows the pointer into a
managed terminal, a passive lower-right popup briefly shows its authoritative
Workspace and terminal names. Expanded Workspace details remain inside the panel
and scroll when their items exceed the available detail surface.

The Agents tab shows **Serve Web via Tailscale** when the gateway is stopped.
Boomux starts it as a detached process only while the daemon is already running,
publishes the dashboard and enabled OpenCode runtime through Tailscale, and
returns the exact MagicDNS URL. **Open Boomux Web** launches that URL in the
default browser. **Stop** shuts down only the gateway and removes only
Boomux-owned Serve routes; unrelated routes and the daemon remain running.

**Create Workspace** first asks whether to use an **Existing Project** or **Create
New**. Existing Project lists the same canonical project names and paths Boomux
discovers from configured `[projects].roots`. Create New requires a Workspace
name and default directory and provides the same local **Browse** surface used by
Shell and Agent forms. Both flows require an explicit eligible Node when Boomux
cannot choose one unambiguously.

For a coordinated Workspace, creation first records the coordinator metadata and
then creates one randomly named pending Shell at the selected path. That Shell
does not start a process, but it establishes the exact Node placement and makes
the directory durable as that placement's default for later Shells. A failure in
the second step leaves the empty Workspace visible and reports the error instead
of inventing or retrying a placement. Remote project paths come only from
Boomux's owner-routed project service; the file browser never interprets them
locally. Legacy local Workspace creation continues to store its default directory
without creating an initial Shell.

Configure the suggestions in Boomux, for example:

```toml
[projects]
roots = ["~/Projects", "~/Work"]
max_depth = 3
```

![Boomux configured project picker](assets/projects.png)

Each locally owned workspace item has a **Remove** button. Remote item removal is
not offered by the panel. Removing a shell, command, or Agent
item closes its exact backing shell, terminates it if running, and deletes its
shell definition and retained terminal state. Durable Agent history may remain
available for acknowledgement. Removing a launcher deletes only that launcher
definition; applications it already launched keep running. Both operations ask
for confirmation before changing the workspace. Removing a Workspace also asks
for confirmation and removes its managed processes, launchers, schedules and
persisted prompts, retained state, Agent and attention records, and metadata. A
coordinated close can remain visibly `closing` when an owner is unavailable or a
placement is still `close_pending`; Boomux retains the unresolved membership
until that owner confirms removal or the close is retried outside the panel.

Opening a complete global Workspace is one Boomux fan-out request. Available
placements start immediately and unavailable owners do not block them. Boomux invokes its launchers,
takes over active terminal controllers, and restarts exited shells. Workspace
restore is non-transactional, so some items can open even if another item fails.
Opening an individual exited shell or command restarts its stored process.

Agent creation records and opens a command-backed shell using the exact
executable returned by the selected Node's Boomux integration status. The
installed lifecycle integration creates the authoritative Agent record after the
coding-agent host starts; the plugin does not fabricate Agent lifecycle state.

Shell and Agent forms request an unreserved generated name from Boomux for the
exact selected owner placement when one already exists. The field remains editable, and typing is never
overwritten by a delayed suggestion. Another client can claim the suggested
name before creation; Boomux remains authoritative and reports that collision.
Both forms expose a **Select Node** dropdown and default it to the eligible local
Node; selecting another Node updates placement-specific name and path defaults.

The bomb icon changes with Agent state. Blocked work uses the urgent color;
finished work uses the accent color. The spark turns yellow while either alert
is active. Agent rows keep a stable Workspace-and-name order while the focused
Agent receives a subtle accent without moving. The **Updated** column uses
the latest lifecycle observation, durable attention observation, or initial
registration time. Use the Agent row's **Dismiss** button or press `D` to clear a
local finished marker and acknowledge durable attention without opening the terminal.
For a locally owned Agent, durable attention is acknowledged with the exact Agent
ID and observation revision. Local blocked attention is also acknowledged when
that Agent reports it is working again. Remote attention remains visible and
must be handled through Boomux outside the panel; it is not cleared by opening
the remote Agent.

The **Schedules** surface activates only when the installed CLI advertises the
required JSON commands and the running daemon supports protocol 25 or newer.
The Schedule dropdown identifies each definition by name and Workspace.
The detail surface shows prompt-free configuration and the latest retained run.
Clicking that run asks Boomux to open its exact active shell run or resume its
exact linked Agent Session; it never restarts the private Schedule runner shell
or substitutes a later run. **Run Now** can start an Agent and its permitted
tool, filesystem, and network activity even while a Schedule is paused.
**Pause** prevents future timed dispatch but does not cancel active work;
**Resume** plans future occurrences without catching up paused time. Execution
failures do not change the bomb's Agent-attention spark. Federated Schedules use
each owner Node's scheduler health. Live remote controls and exact execution
reads include that Node's exact ID and are disabled for cached stale,
reconnecting, unreachable, authentication, identity, or unsupported states.

## Update

```bash
omarchy plugin update io.github.gardnmi.boomux
```

Omarchy rescans plugins after an update; a shell restart is not normally needed.
When `curl` is available, the plugin performs two bounded, read-only HTTPS checks
against fixed GitHub URLs: the latest stable Boomux release and the published
plugin manifest on `main`. Each response has a 64 KiB transfer limit, a five-second
deadline, and redirects are not followed. Newer semantic versions add an
upward-arrow badge, unless an Agent alert count takes precedence, and separate
links to the Boomux release page and plugin repository. Failures are silent. These
links never run the update command or download or install anything automatically.

## Remove

```bash
omarchy plugin remove io.github.gardnmi.boomux
```

Removal deletes only the plugin checkout and its bar entry. It does not remove
Boomux, stop or delete Boomux workspaces, or remove Boomux Agent integrations
and data.

## Data And Privacy

- The plugin checks only the local daemon status once per second without starting
  it. On protocol 38 it consumes local `boomux node snapshot --json`, containing
  coordinator Workspaces plus rich local and bounded prompt-free cached remote
  state. It never polls a remote host itself. Protocol 37 snapshots fall back to
  owner-local grouping; older daemons use the previous local Agent, shell, and
  workspace commands. Prompt-free exact latest-run reads occur only in the Schedules tab.
- The passive `boomux capabilities --json` check gates Schedule support. The
  plugin never requests or displays persisted Schedule prompts. When New
  Workspace opens, the advertised passive `boomux project list --json` command
  scans configured roots without contacting or starting the daemon.
- QML makes no SSH requests and does not read or store credentials. Its only
  direct network access is the bounded startup update check against the fixed
  Boomux GitHub release API and plugin `main` manifest URLs. Every management
  command targets the local Boomux CLI; Boomux owns verified routing,
  authentication, installation confirmation, and its bounded cache.
- QML never invokes Tailscale directly. Capability-gated Web controls call only
  Boomux's JSON lifecycle commands; Boomux owns MagicDNS discovery, Serve
  conflicts, background process readiness, and exact route cleanup.
- The plugin does not persist Node projections, prompts, credentials, attachment
  environments, remote terminal content, remote paths, or routes. The Nodes tab
  displays only prompt-free snapshot health, counts, observed protocol, and
  exact Node identity.
- The directory browser reads names of local readable subdirectories only while
  it is open; it does not read file contents or send paths elsewhere.
- Boomux may deliver one locally deduplicated, bounded reconnect attention digest
  after a verified remote cursor resumes. The plugin presents Boomux's durable
  projected attention after refresh; it does not derive or deliver notifications
  from health changes, execution outcomes, quiet output, or cache reseeds.
- Pane side and width changes mutate the plugin's Omarchy entry through its
  inline settings API. The plugin does not edit Boomux configuration itself;
  **Open Boomux config** delegates that mutation to `boomux config edit`.
- After a locally owned Agent terminal opens successfully, its notification is explicitly
  dismissed, or a blocked Agent reports `working` again, the plugin can run the
  local, revision-conditional `boomux attention acknowledge` command. Attention
  for an Agent whose shell was removed can also be dismissed directly from its
  row.
- Opening the dashboard or a managed shell launches a native terminal process.
- Workspace actions can create or open workspaces, create shells on eligible
  Nodes, remove local shells, and invoke remote or local launchers while removing
  only local launchers. Shell removal can terminate a running
  process and deletes retained terminal state. Launcher removal does not stop
  applications already launched. Workspace restore can run commands, open
  native terminals, disconnect existing writable terminal controllers, and
  restart exited shells.
- Schedule actions can start Agent processes and pause or resume future timed
  dispatch. Opening the latest run can attach its exact active run or launch its
  harness to resume the exact linked session. Schedule actions do not edit
  prompts, cancel executions, or remove Schedules.
- Supported remote opens, creation, launcher invocation, and Schedule actions
  include the resource's structural Node identity. Per-item removal and attention
  acknowledgement remain local-only. Stale rows remain visible but cannot
  launch, mutate, acknowledge, inspect private state, or start owner-side
  processes; offline writes are never queued.
- Protocol 37 and older CLIs do not expose Node context on attention acknowledgment,
  workspace/shell creation, or destructive workspace/shell/launcher mutations.
  Those controls remain disabled for remote owners rather than dropping Node
  identity or accidentally applying an operation locally.

## Troubleshooting

### Boomux is unavailable

Confirm Boomux is installed and healthy:

```bash
command -v boomux
boomux doctor
boomux list --json
```

### Agents appear as terminals

Confirm a lifecycle integration is installed and reporting:

```bash
boomux integration status
boomux agent list --json
```

Restart the coding-agent host after installing or updating its integration.

### The panel looks stale

Right-click the bomb or press `R`. If plugin code was just updated but did not
reload, request a plugin rescan:

```bash
omarchy-shell shell rescanPlugins
```

### A remote Node is stale or unavailable

Agent metadata and Schedule details report relevant owner Node health.
`reconnecting` and `stale` retain the last bounded projection. `unreachable`, `authentication required`,
`identity changed`, `identity conflict`, and `unsupported` require owner or route
attention. Controls remain disabled until Boomux reports a current,
identity-verified `online` observation. Inspect through the local CLI:

```bash
boomux node list --json
boomux node snapshot --json
boomux doctor
```

Use **Create Node** for a new registration so authentication and bootstrap
confirmation stay in the native terminal rather than the panel.

## Development

Deploy the complete working tree while Quickshell is stopped, then restart it:

```bash
mise run restart
```

This makes the installed plugin checkout dirty. Restore or remove local test
changes before using `omarchy plugin update` again.

Validate the repository with:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml SidePane.qml
xmllint --noout assets/bomb.svg assets/bomb-spark.svg
bash -n deploy-local.sh
bun test tests/workspace-model.test.js
mise tasks
git diff --check
boomux --version
boomux capabilities --json
boomux daemon status --json
```

Protocol 38 live validation additionally needs two privacy-safe Nodes to verify
multi-placement grouping, equal-name external collisions, mismatched paths,
health and reconnect behavior, explicit creation placement, exact action routing,
global fan-out, remote PTY attachment, Schedule controls, and reconnect attention
presentation. Do not fabricate Node screenshots or use
private paths, titles, prompts, terminal output, or targets.

## License

The plugin code is licensed under the [MIT License](LICENSE). The bomb icon is
adapted from [Font Awesome Free](https://fontawesome.com/icons/bomb) under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
