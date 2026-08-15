# Omarchy Boomux Development Guide

This repository is an Omarchy Quattro bar plugin for monitoring Boomux Agents
and managing Boomux workspaces. Keep changes small, local-first, and explicit
about operations that can start processes or take over terminals.

## Repository Map

- `Panel.qml`: complete runtime implementation and UI
- `manifest.json`: Omarchy plugin identity and marketplace metadata
- `README.md`: user contract, dependency, safety, and lifecycle documentation
- `assets/bomb.svg`: theme-colored Font Awesome bomb body
- `assets/bomb-spark.svg`: fixed yellow attention spark
- `preview.png`: root marketplace preview
- `assets/agents.png`, `assets/workspaces.png`, `assets/schedules.png`: README screenshots
- `deploy-local.sh`: development-only deployment helper
- `THIRD_PARTY_NOTICES.md`: Font Awesome attribution

The permanent plugin ID is `io.github.gardnmi.boomux`. Never change it after
publication.

## Supported Contract

- Minimum Boomux version: `0.16.0`
- Stable JSON envelope: `boomux.cli/v1`
- Current tested daemon protocol: 27
- Supported Agent hosts: OpenCode and Pi through Boomux lifecycle integrations

Parse JSON only from commands advertised by `boomux capabilities --json`.
Validate `schema`, `command`, and expected `data` fields. Use exact workspace,
shell, launcher, Agent, run, and observation-revision IDs returned by Boomux;
never infer IDs from names, terminal output, process names, or list order.

Preserve exact argument arrays. Do not join stored commands and pass them
through a shell. Do not invoke Boomux private transport commands.

## Runtime Model

The panel has three top-level views:

- **Agents**: active user-shell Agents plus user-shell Agents with outstanding
  durable attention; schedule-owned Agents are excluded by shell ownership
- **Workspaces**: a flat workspace selector and a separate selected-workspace
  detail surface
- **Schedules**: a global Schedule selector with prompt-free details, bounded
  latest-run status, scheduler health, and explicit Run/Pause/Resume actions

Workspace items are projected as:

- `agent`: a current Agent presentation over its backing shell
- `shell`: a login shell
- `command`: a shell with a stored exact command vector
- `launcher`: a detached workspace launcher

Schedule-owned shells are private runner infrastructure. Exclude them from
ordinary workspace items and exclude their Agents from the Agents view. Keep
Schedule, execution, shell, run, and Agent IDs distinct.

Agent creation means creating and opening an `opencode` or `pi` command-backed
shell. The lifecycle integration registers the authoritative Agent later. The
plugin must never fabricate an Agent registration or lifecycle observation.

## Safety Invariants

- Check `boomux daemon status --json` before daemon-backed polling. A stopped
  daemon must remain stopped; the widget must not resurrect it.
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
- Gate Schedule polling and actions on advertised JSON commands plus daemon
  protocol 25 or newer. Poll only after the passive daemon-status check.
- Treat **Run Now** as explicit authorization to start Agent and tool activity.
  Pause affects future dispatch only and must not be presented as cancellation.
- Do not fetch Schedule prompts. Do not infer Agent lifecycle from execution
  state or outcome, and do not use execution failures to light the Agent spark.
- Open only through public `boomux execution open <exact-execution-id>`, which
  revalidates exact-run attachment or exact linked-session resume. Do not open
  Schedule runner shells directly.
- Do not expose execution Cancel, Schedule Remove, or Schedule Edit until their
  public exact-ID safety and confirmation flows are implemented.

## UI Conventions

- Keep **New Workspace** at workspace-section scope.
- Keep **Open**, **Shell**, and **Agent** inside the selected workspace detail
  surface so their target is unambiguous.
- Do not use collapsible workspace cards unless explicitly requested.
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
and workspace snapshots only while the daemon is running. Schedule and latest
execution snapshots are fetched only while the Schedules tab is open. A future
event-driven implementation should retain the passive-daemon invariant and
handle cursor expiry by reacquiring a baseline.

Workspace inspection must preserve selection by stable workspace ID. If a new
selection arrives while an inspection is running, issue the latest requested
inspection after the active process exits.

## Validation

Run all of these before committing:

```bash
omarchy plugin validate .
qmllint -I /usr/share/omarchy/shell Panel.qml
xmllint --noout assets/bomb.svg assets/bomb-spark.svg
bash -n deploy-local.sh
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
- Show Agents, Workspaces, and Schedules views after meaningful UI changes.
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
