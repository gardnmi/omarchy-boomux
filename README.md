# Boomux for Omarchy

An MVP Omarchy Quattro bar plugin for opening existing Boomux terminals.

The plugin polls `boomux list --json` and `boomux attention list --json`. It
highlights blocked agents, keeps completed work visible, and displays every
managed terminal. Click an attention or terminal row, or select it with the
arrow keys and press Enter, to run `boomux open <shell-id>` in a new native
terminal window. Opening an attention item does not acknowledge it.

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
