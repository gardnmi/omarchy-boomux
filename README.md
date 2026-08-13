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

## Requirements

- Omarchy Quattro
- `boomux` on `PATH`

## Install

```bash
omarchy plugin add https://github.com/gardnmi/omarchy-boomux.git --enable
```

The widget is placed in the right bar section by default. Right-click the bar
icon or press `R` in the panel to refresh immediately.

For local testing, copy this repository to
`~/.config/omarchy/plugins/io.github.gardnmi.boomux`, then run:

```bash
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.gardnmi.boomux --section right
```

## Validate

From an Omarchy Quattro checkout:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml
```
