# Critical-review regression validation

The review fixes are covered by executable Bun tests that load the actual QML
JavaScript functions and process-exit handlers into isolated mock environments.
They test callback ordering and identity decisions, not a live compositor.

Run the complete regression suite and release check with the CI-pinned Bun:

```sh
bun test tests
bun scripts/validate-release.js main
```

## Covered regressions

- Queued acknowledgments fail closed when an owning Node disappears, becomes
  stale, changes role/registration, or loses capabilities. Remote argv keeps its
  exact Node; responses must match the owner, Agent, and guarded observation.
- Workspace select/clear intents are consumed once, including failures. Only the
  latest explicitly queued intent follows an active request, and an initial clear
  is never suppressed by an unverified local cache.
- A passive daemon status result from before a create request cannot consume that
  newer request. Fresh explicit status/snapshot generations still validate startup.
- Tree opens resolve the latest exact Node/Shell/run/Agent at activation time and
  acknowledge only after open succeeds, without capturing old attention revisions.
- Guided terminal actions release layer-shell keyboard ownership before launch.
  Re-entering keyboard mode targets the active editor, picker, Settings, or modal;
  delayed callbacks cannot reclaim keyboard ownership after release.
- Malformed or unknown installed versions cannot count as update success.

The plugin retains exact remote routing. A backend that does not support a routed
attention command may reject it; the plugin must report that failure once and
must never retry it as a local command or replay it after reconnecting.

## Manual Omarchy/Wayland checks still required

1. Open the pane in keyboard mode, confirm each guided terminal action, and type
   in the terminal immediately. The pane and edge reservation should remain, but
   the terminal should receive input without an extra shortcut.
2. Open Rename, Create Shell, project/directory pickers, and Settings. Release
   keyboard mode with an outside click or shortcut, then re-enter it. Verify
   typing, Tab, Escape, repeated open/close, and modal interruption.
3. With the daemon stopped and a passive status read in flight, press `+`/`N`.
   Verify exactly one explicit startup/create, based on a fresh snapshot. Ordinary
   passive polling must leave the daemon stopped.
4. With a persisted default Workspace, activate an external Workspace first.
   Verify one clear. Simulate a failed selection and confirm there is no retry
   loop; an explicit later click can retry once.
5. Open a blocked Agent from both pointer and keyboard tree navigation. Verify
   owner-qualified attention clears only after successful open, including after
   the retained row's Shell has restarted or attention revision has changed.
6. Queue attention on a remote behind another acknowledgment, then disconnect or
   forget that Node. Confirm no command is issued against the local Node.

These checks require a real Omarchy/Quickshell/Hyprland environment. Native Bun
and mocked controls do not establish live focus delivery, visual correctness,
expansion frame time, memory use, idle CPU, or battery consumption.
