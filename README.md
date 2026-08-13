# Boomux for Omarchy

An Omarchy Quattro bar plugin for monitoring Boomux Agents and opening managed
terminals.

The plugin polls `boomux list --json` and `boomux agent list --json`. Active
Agents are shown separately with their live `working`, `idle`, or `blocked`
state and durable blocked attention. Shells represented by an Agent are omitted
from the terminal section, so each managed process appears once. Click an Agent
or terminal row, or select it with the arrow keys and press Enter, to run
`boomux open <shell-id>` in a new native terminal window. Opening an Agent does
not acknowledge its attention.

Agent rows use their backing Boomux shell name. The widget also watches live
state transitions: when an Agent changes from `working` to `idle`, the bomb and
a count turn accent-colored and the Agent row shows `finished` until that row is
opened. This completion marker is local to the widget and is separate from
Boomux's durable attention queue. Agent and terminal state is polled once per
second.
The panel's **Open TUI** button launches the Boomux dashboard in a new native
terminal window.
Opening an Agent row conditionally acknowledges its current durable attention
before opening the backing shell. Urgent styling follows the Agent's current
blocked lifecycle state, so it clears when work resumes.

The bomb icon is from [Font Awesome Free](https://fontawesome.com/icons/bomb),
licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
Its spark turns yellow while blocked or finished attention is active.

## Requirements

- Omarchy Quattro
- `boomux` on `PATH`

## Install

```bash
omarchy plugin add https://github.com/gardnmi/omarchy-boomux.git --enable
```

The widget is placed in the right bar section by default. Right-click the bar
icon or press `R` in the panel to refresh immediately.

For local testing from this repository, deploy every plugin asset while the
shell is stopped to avoid partial hot reloads:

```bash
mise run restart
```

The installed checkout will be dirty after local deployment. Restore or remove
the local files before using `omarchy plugin update` again.

## Validate

From an Omarchy Quattro checkout:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml
```
