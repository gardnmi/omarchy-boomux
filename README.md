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
- [Boomux](https://github.com/gardnmi/boomux) `0.13.0` or newer available on
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
| Enter | Open the selected item in its native terminal |
| `N` | Create a workspace |
| `R` | Refresh immediately |
| Escape | Close the panel |

The **Open TUI** button launches the Boomux dashboard in a new native terminal
window. In the Workspaces tab, select a workspace to inspect its items. The
action bar can open that workspace, create another workspace, add a login shell,
or start an OpenCode or Pi Agent shell. Clicking a shell, command, or Agent opens
its managed terminal; clicking a launcher invokes that detached command.

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
omarchy restart shell
```

## Remove

```bash
omarchy plugin remove io.github.gardnmi.boomux
```

Removal deletes only the plugin checkout and its bar entry. It does not remove
Boomux, stop or delete Boomux workspaces, or remove Boomux Agent integrations
and data.

## Data And Privacy

- The plugin runs local `boomux list --json` and `boomux agent list --json`
  commands once per second, along with workspace list and inspect commands.
- It makes no network requests and does not read or store credentials.
- It does not modify Boomux or Omarchy configuration directly.
- Opening an Agent can run the local, revision-conditional
  `boomux attention acknowledge` command before opening its terminal.
- Opening the dashboard or a managed shell launches a native terminal process.
- Workspace actions can create or open workspaces, create shells, and invoke
  existing launchers. Opening a workspace runs all of its launchers and opens
  all of its shells using Boomux's normal restore behavior.

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

Right-click the bomb or press `R`. If plugin code was just updated, run:

```bash
omarchy restart shell
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
