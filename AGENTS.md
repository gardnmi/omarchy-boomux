# Omarchy Boomux Development Guide

This repository is an Omarchy Quattro bar plugin for monitoring Boomux Agents
and Sessions and managing Boomux workspaces. Keep changes small, local-first, and explicit
about operations that can start processes or take over terminals.

## Repository Map

- `Panel.qml`: runtime integration, bar indicator, and pane content
- `SidePane.qml`: configurable layer-shell drawer, focus, animation, and dismissal
- `WorkspaceModel.js`: protocol-51 Session grouping and optional presentation
  context, identity validation, and exact command construction
- `tests/`: focused Bun tests and versioned snapshot fixtures
- `manifest.json`: Omarchy plugin identity and marketplace metadata
- `compatibility.json`: authoritative Boomux schema, protocol, capability, and
  diagnostic release requirements
- `.github/workflows/boomux-compatibility.yml`: credential-free reusable check
  for one exact published Boomux release
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

- Required Boomux daemon protocol: 49; require advertised command and feature
  gates rather than assuming an unreleased semantic version
- Stable JSON envelope: `boomux.cli/v1`
- Current paired-branch daemon protocol: 51; Node helper versions and guided
  upgrade coordination require protocol 41 capabilities, while guided remote
  uninstall requires protocol 48 uninstall coordination on both Nodes
- Session display names are optional protocol-50 behavior. Gate them on
  `session_display_names`, `session.rename`, and `session.reset-name`; do not add
  them to `compatibility.json` requirements or raise the minimum Boomux release.
- Session attention and Git branch context are optional protocol-50 behavior.
  Gate owner actions on `session_presentation_context`, retain empty/null defaults,
  and never derive remote branch context locally.
- Observed Agent working contexts are optional protocol-50 presentation under
  `observed_agent_working_contexts`. Preserve their owner ordering, four-item
  bound, and total count; present `git_branch` as separate launch context and
  rely on the owner to omit that canonical root from observed rows. Never imply
  completeness or derive a remote context locally. Do not add the
  capability to `compatibility.json` requirements.
- Latest Agent attribution, Working Context push status, and worktree status are
  optional protocol-51 presentation under `session_latest_agent_attribution`,
  `session_working_context_push_status`, and `session_working_context_worktree_status`.
  Preserve null defaults. This is bounded no-fetch owner data; do not imply fetched
  state or absence of behind commits. Render only exceptional labels: `Unstaged`
  includes untracked work, `Staged` marks index changes, `↑N` marks ahead commits,
  and `Unpublished` marks no upstream. **Seen** remains the Working Context observation time.
- Persistent Session hiding is optional protocol-51 behavior. Gate it on
  `workspace_session_hiding`, `session.hide`, exact Node eligibility, and a
  positive owner Workspace revision. It is a Workspace-owned presentation
  tombstone, not provider-history or process deletion. Do not persist hidden IDs
  in plugin settings or add the capability to global compatibility requirements.
- Supported Agent hosts come from `integration.status`; currently OpenCode, Pi,
  Claude Code, Codex, and Kiro CLI through Boomux lifecycle integrations

### Compatibility Changes

Update `compatibility.json` whenever the plugin begins requiring a new Boomux
CLI schema, daemon protocol, or advertised capability.

- Release the required Boomux behavior before updating the plugin.
- Set `minimum_boomux` to the first release providing the complete required
  contract.
- Do not raise global requirements for optional, capability-gated features.
- Keep older requirements until the plugin actually stops supporting them.
- Run the oldest/current Boomux compatibility matrix after every requirement
  change.
- When changing the reusable compatibility workflow, release the plugin first,
  then update the immutable workflow and `plugin_ref` pins in Boomux.

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
reimplement its filesystem scanner in the plugin. Workspace creation project
choices are local-only and use the exact returned path. Never browse a remote
path with `FolderListModel` or reinterpret it locally.

Shell-name suggestions come only from advertised `shell.suggest-name` JSON data
for the exact workspace ID. They are unreserved UI defaults: keep them editable,
never overwrite user input with a delayed response, and let creation enforce
uniqueness.

Preserve exact argument arrays. Do not join stored commands and pass them
through a shell. Do not invoke Boomux private transport commands.

Session list and inspect require advertised `session.list`, `session.inspect`,
and `projected_agent_sessions`. Remote catalog reads additionally require a
current online non-stale Node and both local and observed
`typed_node_host_services` and `remote_agent_session_catalog`. Activation
requires the static `exact_session_open` feature and invokes only
`boomux session open SESSION_ID [--node NODE_ID] [--workspace WORKSPACE_ID]`; the plugin must not rebuild
harness resume argv or substitute ordinary Shell opening.
Workspace-scoped discovery starts only while the Session rail is visible for the
currently presented coordinated Workspace. The Workspace-row Session icon must
passively toggle its exact rail, while **Browse Sessions** reveals the rail with
keyboard focus. Opening either entry must present its exact Workspace first; it
must not query whichever Workspace was
active before that presentation completes. Build one request per exact active
eligible placement using the owner Workspace ID, reject returned rows for
another owner. Retain catalog-only rows with zero occurrences. Group exact
attention first, then current Sessions, seven-day recent history, and older
history. History starts collapsed. Retain collapse, search, and exact selection
with that source's in-memory cache; clearing pane privacy clears presentation
state too. Successful activation opens in the source Workspace.
Keep Session totals in the rail header. Do not query other Workspaces eagerly
to populate Workspace-row rollups; that would violate source-scoped lazy
discovery and overstate partial cached results.
Display-name changes require the exact
Session ID, Node, and returned owner Workspace revision; never retry a mutation.
Protocol-49 additive defaults report Workspace revision `0`; browsing and
inspection remain available, but display-name mutation requires a positive
revision. Cache Session catalogs only under the exact source identity and active
placement owner revisions that produced them.
Hide uses `boomux session hide SESSION_ID --workspace WORKSPACE_ID [--node
NODE_ID] --json`, validates the exact returned Node, Session, Workspace, revision,
and `changed`, and invalidates only the originating source cache. Invoke it
directly from the explicit Session-menu action and do not retry an unknown
outcome. There is no unhide action.

## Runtime Model

The sliding main pane has a persistent expandable Workspace tree and two lower
views, plus a user-controlled contextual Session rail on the opposite edge:

- **Workspace tree**: coordinated and external Workspaces, with the currently
  presented Hyprland special Workspace highlighted independently from the
  persisted default; a separate chevron expands Shells, commands, and launchers,
  while the row itself stores the default and opens the Workspace
- **Agents**: active user-shell Agents plus user-shell Agents with outstanding
  durable attention, ordered by their latest authoritative update; private
  runner-owned Agents are excluded by shell ownership; capability-gated controls can start,
  open, and stop Boomux Web through Boomux-owned Tailscale exposure
- **Sessions**: a lazy, cross-Node canonical Agent Session catalog for the
  currently presented coordinated Workspace, ordered by
  newest activity, with structural `(node_id, session_id)` identity, exact
  inspection, Boomux-owned exact activation, coordinated Workspace source
  scopes, and optional owner-authoritative display-name actions
- **Nodes**: a health and version table with selected-Node route, helper and
  control versions, protocol, freshness, workload, eligibility,
  exact identity, guided creation, guided reauthentication, guided upgrade, and
  local registration removal

The main pane must always retain its configured width. Put the Session rail on
the opposite edge (`main-left` means `rail-right` and vice versa), with its own
persisted width, layer-shell namespace, and reservation. Closing the main pane
must also close the rail and release both reservations. The existing passive
Boomux toggle opens only the main pane. Passively open or close a Session rail from
its coordinated Workspace row, or open it with keyboard focus from the action menu;
do not add a second Hyprland binding.

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

- Check `boomux daemon status --json` before daemon-backed polling. Passive pane
  refresh must not resurrect a stopped daemon. Explicit `+`/`N` Workspace
  creation may start it through `workspaceDaemonStartCommand`, then must refresh
  daemon protocol and obtain a fresh authoritative Node snapshot for that exact
  intent before resolving the eligible local Node and constructing one atomic
  create command. Never consume a pre-intent snapshot or fall back to remote.
- QML invokes only the local Boomux CLI and daemon for management. It must not
  invoke SSH, contact a Node directly, store credentials, or handle remote
  bootstrap confirmation. Capability-aware Boomux release discovery must use
  `boomux update status --json`, and replacement must launch only the guided
  `boomux update` command. Older compatible clients may retain the bounded,
  read-only fixed GitHub release check; plugin-version discovery uses the fixed
  published manifest URL. Cap each direct response before collecting stdout and
  do not follow redirects; failures remain silent. **Create Node**, **Update**,
  and **Uninstall Boomux** may only launch Boomux's guided setup, upgrade, or
  remote uninstall flow in a local native terminal. Remote uninstall must pass
  the exact registered Node ID as one argv element, remain distinct from
  local-only **Forget Node**, and never claim success from terminal launch. After
  launching a local Boomux update, poll only `update status` and
  report whether the expected installed version appeared; never treat terminal
  launch as update success. **Authenticate** may likewise launch only Boomux's guided
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
  from the widget. Removing current remote integrations is allowed only through
  the explicitly confirmed, Boomux-owned Node uninstall flow; modified assets
  and durable data remain under Boomux's preservation contract.
- Never invoke Tailscale directly. Gate Web controls on advertised `web.start`,
  `web.status`, and `web.stop`; use only those exact Boomux JSON commands.
  Starting Web is allowed only while the passive daemon check is currently
  online.

## UI Conventions

- Keep immediate generated Workspace creation and the project-folder action at
  Workspace-tree scope. Do not restore Workspace name or arbitrary-path forms.
- Gate **Change Default Path** on protocol 49, `workspace.set-default-cwd`, and
  `workspace_placement_default_cwd`, and expose it only for an active local
  coordinated placement. Existing Shells must not be restarted.
- Keep Workspace expansion separate from activation. The chevron changes only
  local pane state; the row persists the default and performs explicit open
  without dismissing the pane, and makes that opened Workspace the expanded row.
- Local Shell and command rows in the Workspace tree expose **Close** through
  the existing exact-ID confirmation flow. Never close directly from the row or
  derive owner context from whichever Workspace was previously selected.
- Agent and Shell opens from the pane retain the pane. Pointer input outside the
  drawer passes through to applications; only explicit close, Escape while the
  pane owns keyboard focus, or its IPC toggle should hide it.
- Session card body clicks select and toggle context; Enter, the terminal icon,
  and double-click activate. Spin the icon only for the exact active
  request. Keep the collapsed row compact, and reveal labeled launch and
  observed-work context through the card body or Left/Right keyboard controls. Show the effective
  title, override and attention markers, activity age first, lifecycle, and harness metadata,
  but not Agent-instance counts. Show latest Agent attribution only when it
  differs from the harness label. Keep a menu for inline rename, persistent Hide, and conditional attention
  dismissal. Do not add visible Inspect, Reset Name, or alternate destination
  controls. Escape or outside click
  releases keyboard ownership from the rail back to the main pane without
  hiding the rail; only its close button or main-pane close hides it.
  Unsupported activation must
  explain the required Boomux capability rather than silently doing nothing.
  Done and unavailable Sessions remain visible but non-actionable.
- Keep drawer visibility separate from keyboard ownership. Opening or toggling
  the persistent pane is passive; the IPC `focus` action toggles an explicit
  keyboard mode with a contrasting outline, inner-edge wash, and focus rail.
- Keep main-pane and Session-rail keyboard ownership explicit and exclusive.
  Revealing the rail from keyboard mode transfers ownership to it; release from
  the rail returns ownership to the still-visible main pane. Search retains
  ordinary text input and arrows transfer selection to the card list.
- Keyboard mode uses exclusive layer focus until explicit release. Super-modified
  arrow bindings must invoke the pane's IPC focus release before Hyprland's
  native directional focus dispatcher.
- Commit layer keyboard interactivity `None` before releasing keyboard focus.
  Do not infer keyboard ownership from Hyprland's active-window decoration.
- While keyboard mode is active, an outside click may be consumed to release
  keyboard ownership. Passive mode must restore pointer pass-through immediately.
- Keyboard navigation cycles between the Workspace tree, expanded Workspace
  items, and the lower view. Arrow keys move within a section, Enter activates,
  and `M` opens the focused resource's action menu. Menus must retain an enabled
  keyboard cursor and restore the prior section when dismissed.
- Workspace and Agent keyboard cursors must use the same neutral fill. Keep it
  consistent with pointer hover and across keyboard focus changes without adding
  a focus-color border.
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
  Clamp it so both the tree and lower section retain usable space, and preserve
  the tree's current scroll position when dragging ends.
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
- Set the pane key catcher's `blocked` state while text fields own keyboard input.
- Modal confirmations must consume or explicitly handle Enter, Escape, Tab,
  arrows, and text shortcuts instead of leaking input to the panel below.
- Bound every dynamic list with clipping and a scrollbar. The panel content
  height is capped, so unbounded repeaters can make actions inaccessible.
- Keep a bounded outer scroll fallback for short displays and render user-action
  progress or errors in the pane rather than relying only on transient notices.
- Display paths under `$HOME` with `~` to reduce noise and avoid exposing a
  personal absolute path in screenshots.
- Keep the yellow spark visible only for blocked or completed attention at
  runtime. Never hard-code the lit state in source.

## Processes And Errors

Use `Quickshell.Io.Process` with argv arrays. Guard every mutation against a
concurrent process. For user actions, collect both stdout and stderr and surface
an actionable message in the panel. Boomux JSON errors use `error.code` for
program logic; messages are suitable only for display.

Atomic Workspace creation and default-path changes have dedicated Processes.
Validate their exact response IDs and paths, then wait for an authoritative
snapshot with those identities. Never resolve by name, optimistically mutate,
queue offline work, or retry a mutation.
Boomux may canonicalize requested paths: require returned paths to be absolute
and use the returned canonical path for snapshot confirmation. Bound
post-success confirmation and clear busy state with a completed-but-unconfirmed
warning; never replay the successful mutation.

Polling currently checks daemon status once per second and fetches Agent, shell,
and Workspace snapshots only while the daemon is running. With protocol 38 it
groups one combined Node snapshot by coordinator Workspace; protocol 37 uses the
same read with owner-local grouping. Older daemons retain the local list polling
path. A future event-driven implementation should retain the passive-daemon
invariant and handle cursor expiry by reacquiring a baseline.

Session discovery is independent, serial, and lazy while the contextual rail is
open for a presented coordinated Workspace. Refresh it on rail entry, after a
10-second visible TTL, and
after explicit refresh obtains a fresh Node snapshot. Preserve successful Node
results across partial failures, bound warnings, discard stale generations and
Node mismatches. Retain the last complete bounded Session rows in process memory
across pane close, while clearing requests, process output, details, and stale
generations. Render retained rows immediately and refresh them in the background
after TTL expiry. Daemon loss clears the cache. Never persist Session data.
For Workspace-scoped discovery, exclude stale, unavailable, and `close_pending`
placements before constructing argv. Treat Node/owner placement keys as source
identity and placement owner revisions as source freshness. An identity change
clears source-bound rows and selection; freshness-only changes refetch while
preserving qualified selection, search text, and scroll position. Preserve the
exact source Workspace through open and display-name failures. Session
presentation context must match attention by exact Node, owner Workspace, Agent
ID, reason, and observation revision. Selecting never acknowledges attention;
only a successful Session open or explicit Dismiss Attention may queue the exact
guarded acknowledgment.
Do not terminate or forget an in-flight display-name process when the pane or
source scope changes. Validate its exact response and notify the result, but
apply it to an in-memory catalog only when that catalog still has the originating
scope signature. Display-name commands accept only the minimal result envelope:
`data.result` carries Session ID, owner Workspace ID, effective user display
name, Workspace revision, and `changed`; remote responses additionally carry
`data.node_id`. Fresh and exactly replayed successful responses both carry
exactly the requested Workspace revision plus one.
Do not terminate or forget an in-flight Session hide when the pane or source
scope changes. Validate the minimal owner result before removing the exact row.
Apply it directly only when the originating source is still current; otherwise
drop only that source's cache. A changed result advances the listed Workspace
revision by one; `changed: false` retains it. Never retry the mutation after an
ambiguous result.

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
bun test tests/compatibility.test.js
bun scripts/validate-release.js
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
- Show Agents, Sessions, Workspaces, and Nodes views after meaningful UI changes.
- Do not expose personal absolute paths, secrets, private session titles, or
  terminal contents.
- To demonstrate the yellow spark, temporarily force the **deployed test copy**
  to show it, capture the image, then redeploy from source and verify the files
  match. Never commit a forced lit state.

## Documentation And Release Checklist

- Change Boomux requirements only in `compatibility.json`; keep runtime checks,
  README guidance, and release tests derived from that declaration.
- Update `manifest.json` semantically: patch for fixes/docs, minor for new user
  features, major for incompatible behavior.
- Keep `main` release-ready. Successful CI for the current `main` commit creates
  the immutable `v<manifest version>` tag and GitHub release; every pull request
  must therefore advance the manifest version.
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
