# Omarchy Boomux Development Guide

This repository is an Omarchy Quattro bar plugin for monitoring Boomux Agents
and managing Boomux workspaces. Keep changes small, local-first, and explicit
about operations that can start processes or take over terminals.

## Repository Map

- `Panel.qml`: runtime integration, bar indicator, and pane content
- `SidePane.qml`: configurable layer-shell drawer, focus, animation, and dismissal
- `WorkspaceModel.js`: protocol-38 grouping and qualified command construction
- `tests/`: focused Bun tests and versioned snapshot fixtures
- `manifest.json`: Omarchy plugin identity and marketplace metadata
- `README.md`: user contract, dependency, safety, and lifecycle documentation
- `assets/bomb.svg`: theme-colored Font Awesome bomb body
- `assets/bomb-spark.svg`: fixed yellow attention spark
- `preview.png`: root marketplace preview
- `assets/boomux-workspace-desktop.png`: current side-pane README screenshot
- `deploy-local.sh`: development-only deployment helper
- `THIRD_PARTY_NOTICES.md`: Font Awesome attribution

The permanent plugin ID is `io.github.gardnmi.boomux`. Never change it after
publication.

## Supported Contract

- Planned minimum released Boomux version: `0.27.0`
- Stable JSON envelope: `boomux.cli/v1`
- Current branch-validated daemon protocol: 44; Node helper versions and guided
  upgrade coordination require protocol 41 capabilities
- Supported Agent hosts come from `integration.status`; currently OpenCode, Pi,
  Claude Code, Codex, and Kiro CLI through Boomux lifecycle integrations

Parse JSON only from commands advertised by `boomux capabilities --json`.
Validate `schema`, `command`, and expected `data` fields. Use exact workspace,
shell, launcher, Agent, run, and observation-revision IDs returned by Boomux;
never infer IDs from names, terminal output, process names, or list order.

Federation requires advertised `node.snapshot`, `combined_node_snapshot`,
`node_qualified_dashboard`, and `typed_exact_node_routing` support. Global
Workspace grouping additionally requires `global_workspaces` and
`multi_node_workspace_placements`. Keep the
installed CLI capability, local daemon protocol, and each remote Node's observed
capabilities distinct. Every projected and pending resource identity is the
structural pair `(node_id, resource_id)`; bare IDs are never globally unique.
Preserve nullable Node `route`, `registration_revision`, and
`observed_helper_version` fields. Compare helper versions only as valid semantic
release versions. Offer replacement only when the remote helper is older than
the control CLI; a newer remote requires updating the control machine and must
never be downgraded by the pane.

Project suggestions come only from advertised `project.list` JSON data. Keep
project discovery passive and on-demand; do not parse Boomux configuration or
reimplement its filesystem scanner in the plugin.
Remote project and path suggestions must use `project list --node` on the owner.
Never browse a remote path with `FolderListModel` or reinterpret it locally.

Shell-name suggestions come only from advertised `shell.suggest-name` JSON data
for the exact workspace ID. They are unreserved UI defaults: keep them editable,
never overwrite user input with a delayed response, and let creation enforce
uniqueness.

Preserve exact argument arrays. Do not join stored commands and pass them
through a shell. Do not invoke Boomux private transport commands.

## Runtime Model

The sliding pane has a persistent expandable Workspace tree and two lower views:

- **Workspace tree**: coordinated and external Workspaces, with the currently
  presented Hyprland special Workspace highlighted independently from the
  persisted default; a separate chevron expands Shells, commands, and launchers,
  while the row itself stores the default and opens the Workspace
- **Agents**: active user-shell Agents plus user-shell Agents with outstanding
  durable attention, ordered by their latest authoritative update; private
  runner-owned Agents are excluded by shell ownership; capability-gated controls can start,
  open, and stop Boomux Web through Boomux-owned Tailscale exposure
- **Nodes**: a health and version table with selected-Node route, helper and
  control versions, protocol, freshness, workload, eligibility,
  exact identity, guided creation, guided reauthentication, guided upgrade, and
  local registration removal

The header Settings surface owns pane-local presentation settings. Side and
width changes persist through Omarchy's inline plugin settings API. Opening the
Boomux configuration must delegate to `boomux config edit` so Boomux resolves
the active writable configuration layer; the plugin must not guess that path.

Protocol 38 adds coordinator-owned global Workspaces with explicit Node
placements. Keep Workspace grouping task-first; show Node ownership as secondary
metadata rather than a filter or Node-first path. Every stable health value (`unobserved`, `online`,
`reconnecting`, `stale`, `unreachable`, `authentication_required`,
`identity_changed`, `identity_conflict`, and `unsupported`) remains visible.
Cached stale rows are presentation only and all owner-dependent actions are
disabled. Guided Node upgrade is the sole stale-row exception: it must use the
exact registered Node ID and delegate live route, authentication, identity, and
replacement validation to Boomux.

Never merge owner Workspaces by name. Global membership comes only from explicit
placements; unlinked owner Workspaces remain qualified external singletons.
Protocol 37 and older snapshot shapes retain their owner-local presentation.

Workspace items are projected as:

- `agent`: a current Agent presentation over its backing shell
- `shell`: a login shell
- `command`: a shell with a stored exact command vector
- `launcher`: a detached workspace launcher

Legacy mixed-version snapshots can include schedule-owned Shells as private
runner infrastructure. Preserve string and object owner parsing only to exclude
those Shells from Workspace items and their Agents from the Agents view. Do not
otherwise expose or process scheduled work.

Agent creation means creating and opening a command-backed shell with the exact
available executable returned by `integration.status` for the selected Node.
Require a current lifecycle asset. The lifecycle integration registers the
authoritative Agent later. The plugin must never fabricate an Agent registration
or lifecycle observation.

## Safety Invariants

- Check `boomux daemon status --json` before daemon-backed polling. A stopped
  daemon must remain stopped; the widget must not resurrect it.
- QML invokes only the local Boomux CLI and daemon for management. It must not
  invoke SSH, contact a Node directly, store credentials, or handle remote
  bootstrap confirmation. Capability-aware Boomux release discovery must use
  `boomux update status --json`, and replacement must launch only the guided
  `boomux update` command. Older compatible clients may retain the bounded,
  read-only fixed GitHub release check; plugin-version discovery uses the fixed
  published manifest URL. Cap each direct response before collecting stdout and
  do not follow redirects; failures remain silent. **Create Node** and **Update**
  may only launch Boomux's guided setup or upgrade wrapper in a local native
  terminal. **Authenticate** may likewise launch only Boomux's guided
  reauthentication wrapper for an `authentication_required` Node when the local
  CLI advertises `node_reauthentication` and daemon protocol 38 is available.
  Pass the exact Node ID as one argv element; never interpolate it into a shell
  command.
- Consume federation through `boomux node snapshot --json`. Pass exact `--node`
  context to every supported remote open, inspect, host service, attention, and
  mutation command. Never queue an offline action.
- Opening an exited shell or command starts a new run. Preserve clear status in
  the item row and document this behavior.
- Acknowledge Agent attention only after `boomux open` succeeds, the user
  explicitly dismisses its notification, or that same Agent reports `working`
  after blocked attention.
- Queue acknowledgements and use the exact Agent ID plus attention observation
  revision. Do not optimistically hide durable attention before CLI success.
- Durable attention is authoritative even when the current Agent state has
  advanced. Derive blocked/completed attention from `agent.attention`, not only
  from `agent.observation.state`.
- A removed backing shell cannot be opened. If adding actions for historical
  attention, use Boomux attention metadata and provide an acknowledgement path
  that does not pretend the shell is retained.
- Never overwrite user configuration or install/replace Boomux integrations
  from the widget.
- Never invoke Tailscale directly. Gate Web controls on advertised `web.start`,
  `web.status`, and `web.stop`; use only those exact Boomux JSON commands.
  Starting Web is allowed only while the passive daemon check is currently
  online.

## UI Conventions

- Keep **Create Workspace** at Workspace-tree scope.
- Keep Workspace expansion separate from activation. The chevron changes only
  local pane state; the row persists the default and performs explicit open
  without dismissing the pane, and makes that opened Workspace the expanded row.
- Local Shell and command rows in the Workspace tree expose **Close** through
  the existing exact-ID confirmation flow. Never close directly from the row or
  derive owner context from whichever Workspace was previously selected.
- Agent and Shell opens from the pane retain the pane. Pointer input outside the
  drawer passes through to applications; only explicit close, Escape while the
  pane owns keyboard focus, or its IPC toggle should hide it.
- Keep **Create Node** at Nodes-section scope; do not add a Node filter.
- Keep **Update** beside the affected remote Node's **Create Shell** action. Show
  it only for an older helper with both local and observed remote upgrade
  capabilities. For a newer helper, show **Control machine update needed** and
  no replacement action.
- Show a local Boomux update only when the latest stable version is newer. When
  `local_update_status` and `guided_local_update` are advertised, delegate status
  and authorization to those commands in a native terminal; never download or
  replace the CLI from QML. Older clients may open only the release page.
- Replace the unavailable **Create Shell** action with **Authenticate** only for
  an `authentication_required` remote Node when the installed CLI advertises
  `node_reauthentication` and daemon protocol 38 is available. Delegate route,
  identity, helper, prompt-free retry, and registration validation to Boomux in
  a native terminal.
- Keep Node rows card-like and scannable: name plus one compact health/version
  line and a small action group. The selected summary shows route, runtime, and
  combined workload; health detail, control-version warnings, and eligibility
  failures appear only when exceptional. Do not restore a dense
  diagnostics table or an always-visible metadata wall.
- Highlight only the Hyprland-presented special Workspace as active. Persisted
  default and expanded Workspace state must remain visually distinct.
- The divider above the lower tabs resizes the Workspace viewport vertically.
  Clamp it so both the tree and lower section retain usable space, and reposition
  the expanded Workspace when dragging ends.
- Mark a focused Workspace item only from the exact qualified Shell identity of
  Hyprland's active managed terminal. Never mark a launcher or match by name.
  Focus styling must remain a subtle accent and must not reorder Agent rows.
- While open, the side pane owns a transparent layer-shell exclusive zone on its
  configured edge so tiled windows reflow beside it. Closing the pane must
  release that reservation; the overlay surface still owns input and animation.
- The Boomux side pane is persistent and must not join the bar's single-popout
  coordinator. Opening another plugin may temporarily own input above it but
  must not close Boomux or release its reservation.
- Use Omarchy `qs.Ui` controls and `Style.space(...)`; follow the active bar
  foreground, urgent color, font, and accent.
- Set `PanelKeyCatcher.blocked` while text fields own keyboard input.
- Modal confirmations must consume or explicitly handle Enter, Escape, Tab,
  arrows, and text shortcuts instead of leaking input to the panel below.
- Bound every dynamic list with clipping and a scrollbar. The panel content
  height is capped, so unbounded repeaters can make actions inaccessible.
- Display paths under `$HOME` with `~` to reduce noise and avoid exposing a
  personal absolute path in screenshots.
- Keep the yellow spark visible only for blocked or completed attention at
  runtime. Never hard-code the lit state in source.

## Processes And Errors

Use `Quickshell.Io.Process` with argv arrays. Guard every mutation against a
concurrent process. For user actions, collect both stdout and stderr and surface
an actionable message in the panel. Boomux JSON errors use `error.code` for
program logic; messages are suitable only for display.

Polling currently checks daemon status once per second and fetches Agent, shell,
and Workspace snapshots only while the daemon is running. With protocol 38 it
groups one combined Node snapshot by coordinator Workspace; protocol 37 uses the
same read with owner-local grouping. Older daemons retain the local list polling
path. A future event-driven implementation should retain the passive-daemon
invariant and handle cursor expiry by reacquiring a baseline.

Workspace inspection must preserve selection by structural Node/workspace key.
If a new selection arrives while an inspection is running, issue the latest
requested inspection after the active process exits.

## Validation

Run all of these before committing:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml SidePane.qml
xmllint --noout assets/bomb.svg assets/bomb-spark.svg
bash -n deploy-local.sh
bun test tests/workspace-model.test.js
mise tasks
git diff --check
```

Also verify the installed dependency and public CLI surface:

```bash
boomux --version
boomux capabilities --json
boomux daemon status --json
```

For a live smoke test:

```bash
mise run restart
omarchy-shell io.github.gardnmi.boomux open
```

`mise run restart` stops Quickshell, copies the complete runtime plugin, and
restarts the shell to avoid partial hot-reload races. It intentionally makes the
installed plugin checkout dirty. Do not include that installed checkout in Git
work here.

## Screenshots

- Screenshots must be captured from the real plugin UI and owned by the project.
- `preview.png` is the marketplace image; keep it in the repository root.
- README image URLs should use stable files under `assets/`. Use a new filename
  if GitHub serves stale image content for an unchanged path.
- Show Agents, Workspaces, and Nodes views after meaningful UI changes.
- Do not expose personal absolute paths, secrets, private session titles, or
  terminal contents.
- To demonstrate the yellow spark, temporarily force the **deployed test copy**
  to show it, capture the image, then redeploy from source and verify the files
  match. Never commit a forced lit state.

## Documentation And Release Checklist

- Keep the README minimum Boomux version synchronized with every CLI command
  used by `Panel.qml`.
- Update `manifest.json` semantically: patch for fixes/docs, minor for new user
  features, major for incompatible behavior.
- Keep install, update, remove, daemon behavior, external dependencies, process
  effects, privacy boundaries, and destructive-operation disclosures accurate.
- The manifest license is `MIT AND CC-BY-4.0`: code is MIT and adapted Font
  Awesome icon geometry is CC BY 4.0.
- Confirm root `README.md`, `LICENSE`, `manifest.json`, and `preview.png` exist.
- Confirm the public default branch contains the final commit before submitting;
  marketplace validation inspects the current public commit.
- Recommended marketplace category: `Developer Tools`.
- Recommended tags: `AI`, `Bar`, `Workspaces`.
- Submit a fresh marketplace issue after a withdrawn submission; do not reopen a
  stale validation tied to an older plugin version.
