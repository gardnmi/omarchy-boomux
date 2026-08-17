# Boomux for Omarchy

Monitor interactive Boomux Agents, manage coordinator-owned global Workspaces
across federated Nodes, and operate recurring Agent Schedules without leaving the
Omarchy bar.

![Boomux Agent status in the Omarchy bar](assets/agents.png)

## Features

- Keeps active Agents in a dedicated status tab
- Excludes schedule-owned Agents handled by Boomux scheduling
- Shows live `working`, `idle`, and `blocked` Agent states
- Highlights finished work and blocked attention in the bar
- Keeps finished markers visible until you open the corresponding Agent
- Groups Shells, Agents, launchers, and Schedules by global Workspace task
- Shows resources from multiple Node placements and their placement-specific paths
- Opens complete workspaces or individual managed items
- Removes individual workspace items after confirming their specific impact
- Creates workspaces from configured project suggestions or a custom directory
- Opens an in-panel directory picker for workspace, shell, and Agent directories
- Prefills editable shell and Agent names from Boomux suggestions
- Starts new OpenCode or Pi command shells and lets their lifecycle integration
  register the Agent
- Acknowledges current durable attention when you open its Agent
- Lists Schedules across workspaces with scheduler status and their latest run
- Runs Schedules immediately and pauses or resumes future timed dispatch
- Launches the full Boomux TUI in a new native terminal
- Supports mouse and keyboard navigation and follows the active Omarchy theme
- Polls local Boomux state once per second for responsive updates
- Keeps Node ownership as secondary metadata instead of a Node filter or Node-first label
- Shows every placement and Node health state without hiding cached stale resources
- Keeps equal-name unlinked Node-local Workspaces as distinct external Workspaces
- Shows scheduler health independently per Node and disables owner-dependent
  actions while its state is stale or unavailable
- Opens interactive **Add Node** setup only in a local native terminal

![Boomux workspace management in the Omarchy bar](assets/workspaces.png)

![Boomux Schedule management in the Omarchy bar](assets/schedules.png)

## Requirements

- Omarchy with the Quattro shell plugin system
- [Boomux](https://github.com/gardnmi/boomux) `0.19.0` or newer available on
  `PATH`
- A configured native terminal supported by `xdg-terminal-exec`

Boomux `0.19.0` is the planned first release containing protocol 38. Until that
release is tagged, global Workspace support is branch-validated against Boomux
PR 207 and requires a matching protocol-38 Boomux build. The currently installed
`0.18.0` binary provides only the protocol-37 fallback and is not live evidence
for global Workspace behavior.

Workspace management works with Boomux alone. Agent states and Agent creation
require the corresponding coding-agent executable and Boomux lifecycle
integration. For OpenCode or Pi, run:

```bash
boomux integration setup opencode
# or
boomux integration setup pi
```

The plugin does not automatically start a stopped Boomux daemon. Launch Boomux
or open a managed workspace before using the panel.

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

## Use

| Input | Action |
| --- | --- |
| Left click | Open or close the panel |
| Right click | Refresh immediately |
| Tab or `1` / `2` / `3` | Switch between Agents, Workspaces, and Schedules |
| `A` | Open interactive Add Node in a native terminal |
| Up / Down | Select an Agent, workspace, or Schedule |
| Enter | Open a selected Agent or select a workspace or Schedule |
| `D` | Dismiss the selected Agent notification |
| `N` | Create a workspace |
| `R` | Refresh immediately |
| Escape | Close the panel |

The **Open TUI** button launches the Boomux dashboard in a new native terminal
window. **Add Node** remains beside it and opens local interactive `boomux node add`
in a native terminal, where Boomux alone handles SSH authentication, remote
install details, and confirmation. The terminal remains open after setup so its
success or failure is visible. Selecting a Workspace shows its Node
placements, placement-specific directories and health, items, and scoped
**Open**, **Shell**, and **Agent** actions below the
workspace list. Clicking a shell, command, or Agent opens its managed terminal;
clicking a launcher invokes that detached command. Opening a managed terminal
takes over its writable controller so the new window receives the authoritative
terminal size and input stream. Expanded Workspace details remain inside the
panel and scroll when their items exceed the available detail surface.

**New Workspace** creates coordinator metadata and opens with the same projects Boomux discovers from configured
`[projects].roots`. Search and select a project to use its canonical name and
path, or choose **Custom** to enter an unrelated workspace name and optional
default directory. **Browse** opens a bounded local directory browser and fills
the exact selected path; manual path entry remains available. Choosing a project
or directory does not create or start anything until **Create** is pressed.
For a project or custom directory, the plugin calls the single atomic
`boomux workspace create-project --json` flow, which returns the exact global
Workspace, owner Node, owner Workspace, and first Shell identities. Boomux
revalidates the exact sole eligible Node selected by the UI; when several are
eligible, the form requires an explicit Node choice and passes its exact ID. The
panel never invents a default placement. Remote paths are never opened in the
local directory browser. Any remote project
or path data comes from Boomux's owner-routed `project list --node` service;
unsupported remote creation controls stay disabled.

Configure the suggestions in Boomux, for example:

```toml
[projects]
roots = ["~/Projects", "~/Work"]
max_depth = 3
```

![Boomux configured project picker](assets/projects.png)

Each workspace item has a **Remove** button. Removing a shell, command, or Agent
item closes its exact backing shell, terminates it if running, and deletes its
shell definition and retained terminal state. Durable Agent history may remain
available for acknowledgement. Removing a launcher deletes only that launcher
definition; applications it already launched keep running. Both operations ask
for confirmation before changing the workspace.

Opening a complete global Workspace is one Boomux fan-out request. Available
placements start immediately while unavailable placements remain visible and
Boomux reports per-Node failures. Boomux invokes its launchers,
takes over active terminal controllers, and restarts exited shells. Workspace
restore is non-transactional, so some items can open even if another item fails.
Opening an individual exited shell or command restarts its stored process.

Agent creation records and opens a command-backed shell whose exact command is
`opencode` or `pi`. The installed lifecycle integration creates the authoritative
Agent record after the coding-agent host starts; the plugin does not fabricate
Agent lifecycle state.

Shell and Agent forms request an unreserved generated name from Boomux for the
exact selected owner placement when one already exists. The field remains editable, and typing is never
overwritten by a delayed suggestion. Another client can claim the suggested
name before creation; Boomux remains authoritative and reports that collision.
Both forms expose a **Select Node** dropdown and default it to the eligible local
Node; selecting another Node updates placement-specific name and path defaults.

The bomb icon changes with Agent state. Blocked work uses the urgent color;
finished work uses the accent color. The spark turns yellow while either alert
is active. Use the Agent row's **Dismiss** button or press `D` to clear a local
finished marker and acknowledge durable attention without opening the terminal.
Durable attention is acknowledged with the exact Agent ID and observation
revision. Blocked attention is also acknowledged when that Agent reports it is
working again. Failed acknowledgements remain visible for manual dismissal.

The **Schedules** surface activates only when the installed CLI advertises the
required JSON commands and the running daemon supports protocol 25 or newer.
Schedule rows show their durable paused or enabled state and next occurrence.
The detail surface shows prompt-free configuration and the latest retained run.
Clicking that run asks Boomux to open its exact active shell run or resume its
exact linked Agent Session; it never restarts the private Schedule runner shell
or substitutes a later run. **Run Now** can start an Agent and its permitted
tool, filesystem, and network activity even while a Schedule is paused.
**Pause** prevents future timed dispatch but does not cancel active work;
**Resume** plans future occurrences without catching up paused time. Execution
failures do not change the bomb's Agent-attention spark. Federated Schedule rows
use each owner Node's scheduler health. Live remote controls and exact execution
reads include that Node's exact ID and are disabled for cached stale,
reconnecting, unreachable, authentication, identity, or unsupported states.

## Update

```bash
omarchy plugin update io.github.gardnmi.boomux
```

Omarchy rescans plugins after an update; a shell restart is not normally needed.

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
- QML makes no SSH or other network requests and does not read or store
  credentials. Every command targets the local Boomux CLI; Boomux owns verified
  routing, authentication, installation confirmation, and its bounded cache.
- The plugin does not persist Node projections, prompts, credentials, attachment
  environments, remote terminal content, or remote paths.
- The directory browser reads names of local readable subdirectories only while
  it is open; it does not read file contents or send paths elsewhere.
- Boomux may deliver one locally deduplicated, bounded reconnect attention digest
  after a verified remote cursor resumes. The plugin presents Boomux's durable
  projected attention after refresh; it does not derive or deliver notifications
  from health changes, execution outcomes, quiet output, or cache reseeds.
- It does not modify Boomux or Omarchy configuration directly.
- After an Agent terminal opens successfully, its notification is explicitly
  dismissed, or a blocked Agent reports `working` again, the plugin can run the
  local, revision-conditional `boomux attention acknowledge` command. Attention
  for an Agent whose shell was removed can also be dismissed directly from its
  row.
- Opening the dashboard or a managed shell launches a native terminal process.
- Workspace actions can create or open workspaces, create or remove shells, and
  invoke or remove existing launchers. Shell removal can terminate a running
  process and deletes retained terminal state. Launcher removal does not stop
  applications already launched. Workspace restore can run commands, open
  native terminals, disconnect existing writable terminal controllers, and
  restart exited shells.
- Schedule actions can start Agent processes and pause or resume future timed
  dispatch. Opening the latest run can attach its exact active run or launch its
  harness to resume the exact linked session. Schedule actions do not edit
  prompts, cancel executions, or remove Schedules.
- Remote opens and mutations include the resource's structural Node identity.
  Stale rows remain visible but cannot launch, mutate, acknowledge, inspect
  private state, or start owner-side processes; offline writes are never queued.
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

Secondary status text reports Boomux's stable Node health value. `reconnecting` and `stale`
retain the last bounded projection. `unreachable`, `authentication required`,
`identity changed`, `identity conflict`, and `unsupported` require owner or route
attention. Controls remain disabled until Boomux reports a current,
identity-verified `online` observation. Inspect through the local CLI:

```bash
boomux node list --json
boomux node snapshot --json
boomux doctor
```

Use **Add Node** for a new registration so authentication and bootstrap
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
qmllint -I /usr/share/omarchy/shell Panel.qml
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
