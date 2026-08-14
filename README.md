# Boomux for Omarchy

Monitor every Boomux Agent and manage native-terminal workspaces without leaving
the Omarchy bar.

![Boomux Agent status in the Omarchy bar](assets/agents.png)

## Features

- Keeps active Agents in a dedicated status tab
- Shows live `working`, `idle`, and `blocked` Agent states
- Highlights finished work and blocked attention in the bar
- Keeps finished markers visible until you open the corresponding Agent
- Lists workspaces and their Agent, shell, command, and launcher items
- Opens complete workspaces or individual managed items
- Creates workspaces and pending login shells
- Starts new OpenCode or Pi command shells and lets their lifecycle integration
  register the Agent
- Acknowledges current durable attention when you open its Agent
- Launches the full Boomux TUI in a new native terminal
- Supports mouse and keyboard navigation and follows the active Omarchy theme
- Polls local Boomux state once per second for responsive updates

![Boomux workspace management in the Omarchy bar](assets/workspaces.png)

## Requirements

- Omarchy with the Quattro shell plugin system
- [Boomux](https://github.com/gardnmi/boomux) `0.14.0` or newer available on
  `PATH`
- A configured native terminal supported by `xdg-terminal-exec`

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
| Tab or `1` / `2` | Switch between Agents and Workspaces |
| Up / Down | Select an Agent or workspace |
| Enter | Open a selected Agent or load the selected workspace details |
| `N` | Create a workspace |
| `R` | Refresh immediately |
| Escape | Close the panel |

The **Open TUI** button launches the Boomux dashboard in a new native terminal
window. **New Workspace** is a global action. Selecting a workspace shows its
directory, items, and scoped **Open**, **Shell**, and **Agent** actions below the
workspace list. Clicking a shell, command, or Agent opens its managed terminal;
clicking a launcher invokes that detached command.

Opening a complete workspace requires confirmation because Boomux invokes its
launchers, takes over active terminal controllers, and restarts exited shells.
Workspace restore is non-transactional, so some items can open even if another
item fails. Opening an individual exited shell or command restarts its stored
process.

Agent creation records and opens a command-backed shell whose exact command is
`opencode` or `pi`. The installed lifecycle integration creates the authoritative
Agent record after the coding-agent host starts; the plugin does not fabricate
Agent lifecycle state.

The bomb icon changes with Agent state. Blocked work uses the urgent color;
finished work uses the accent color. The spark turns yellow while either alert
is active. Finished markers are local to this widget and clear when you open the
corresponding Agent. Durable blocked attention is conditionally acknowledged
with the exact Agent ID and observation revision when that Agent is opened.

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

- The plugin checks local daemon status once per second without starting it. If
  Boomux is already running, it polls Agent, shell, and workspace state once per
  second and inspects the selected workspace.
- It makes no network requests and does not read or store credentials.
- It does not modify Boomux or Omarchy configuration directly.
- After an Agent terminal opens successfully, the plugin can run the local,
  revision-conditional `boomux attention acknowledge` command. Attention for an
  Agent whose shell was removed can be acknowledged directly from its row.
- Opening the dashboard or a managed shell launches a native terminal process.
- Workspace actions can create or open workspaces, create shells, and invoke
  existing launchers. Confirmed workspace restore can run commands, open native
  terminals, disconnect existing writable terminal controllers, and restart
  exited shells.

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
```

## License

The plugin code is licensed under the [MIT License](LICENSE). The bomb icon is
adapted from [Font Awesome Free](https://fontawesome.com/icons/bomb) under
[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
