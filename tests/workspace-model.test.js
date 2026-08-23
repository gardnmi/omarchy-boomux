const { describe, expect, test } = require("bun:test")
const fs = require("node:fs")
const model = require("../WorkspaceModel.js")
const protocol38Envelope = require("./fixtures/protocol38-multi-node.json")
const protocol37Envelope = require("./fixtures/protocol37-local.json")

function normalized(envelope = protocol38Envelope) {
  return model.normalizeNodeSnapshot(model.parseEnvelope(envelope, "node.snapshot"))
}

test("compares only valid semantic release versions", () => {
  expect(model.versionIsNewer("v0.18.1", "0.18.0")).toBe(true)
  expect(model.versionIsNewer("0.19.0", "0.18.9")).toBe(true)
  expect(model.versionIsNewer("0.18.0", "0.18.0")).toBe(false)
  expect(model.versionIsNewer("0.17.9", "0.18.0")).toBe(false)
  expect(model.versionIsNewer("main", "0.18.0")).toBe(false)
})

test("sorts Agents by their latest authoritative update", () => {
  const agents = [
    { key: "older", started_at_ms: 100, observation: { observed_at_ms: 200 } },
    { key: "attention", started_at_ms: 100, observation: { observed_at_ms: 250 },
      attention: { observation: { observed_at_ms: 400 } } },
    { key: "newer", started_at_ms: 100, observation: { observed_at_ms: 300 } }
  ]
  expect(model.agentsByLastUpdated(agents).map(agent => agent.key))
    .toEqual(["attention", "newer", "older"])
  expect(agents.map(agent => agent.key)).toEqual(["older", "attention", "newer"])
})

test("formats compact relative Agent update times", () => {
  const now = 1_000_000_000
  expect(model.relativeTime(now - 20_000, now)).toBe("now")
  expect(model.relativeTime(now - 5 * 60_000, now)).toBe("5m ago")
  expect(model.relativeTime(now - 2 * 60 * 60_000, now)).toBe("2h ago")
  expect(model.relativeTime(now - 3 * 24 * 60 * 60_000, now)).toBe("3d ago")
  expect(model.relativeTime(0, now)).toBe("unknown")
})

test("builds qualified command palette entries and filters their metadata", () => {
  const workspace = { key: "global\u001fworkspace", id: "workspace", name: "Release",
    is_global: true }
  const items = [
    { key: "node-a\u001fshared", kind: "agent", name: "review", node_alias: "local",
      status: "working", detail: "opencode" },
    { key: "node-a\u001fshared", kind: "launcher", name: "server", node_alias: "local",
      status: "on workspace open", detail: "bun run dev" }
  ]
  const nodes = [
    { node_id: "node-a", alias: "local", workspace_owner_eligible: true },
    { node_id: "node-b", alias: "build", workspace_owner_eligible: true }
  ]
  const schedules = [{ key: "node-a\u001fschedule", workspace_key: workspace.key,
    name: "nightly", state: "enabled", node_alias: "local", integration: "opencode" }]
  const entries = model.paletteEntries("items", workspace, items, [workspace], nodes,
    "node-b", schedules)
  expect(entries.map(entry => entry.action)).toEqual([
    "choose-workspace", "create-workspace", "open-workspace", "open-agents",
    "open-shells", "invoke-launchers", "view-schedules", "create-shell",
    "start-agent", "switch-node", "create-node", "remove-workspace"
  ])
  expect(entries.find(entry => entry.action === "create-shell").subtitle).toContain("build")
  const agentEntries = model.paletteEntries("agents", workspace, items, [workspace], nodes,
    "node-b", schedules)
  const launcherEntries = model.paletteEntries("launchers", workspace, items, [workspace],
    nodes, "node-b", schedules)
  expect(agentEntries.concat(launcherEntries).map(entry => entry.id)).toEqual([
    "item:terminal:node-a\u001fshared", "item:launcher:node-a\u001fshared"
  ])
  expect(model.filterPaletteEntries(launcherEntries, "BUN RUN").map(entry => entry.title))
    .toEqual(["server"])
  expect(model.filterPaletteEntries(agentEntries.concat(launcherEntries), "local")
    .map(entry => entry.title))
    .toEqual(["review", "server"])
  expect(model.filterPaletteEntries(entries, "switch node").map(entry => entry.title))
    .toEqual(["Switch Node..."])
  expect(model.paletteEntries("schedules", workspace, items, [workspace], nodes, "node-b",
    schedules)).toEqual([expect.objectContaining({
    action: "view-schedule", schedule_key: "node-a\u001fschedule", title: "nightly"
  })])
})

test("limits palette switching to coordinated Workspaces and eligible Nodes", () => {
  const current = { key: "global\u001fone", name: "one", is_global: true }
  const next = { key: "global\u001ftwo", name: "two", is_global: true }
  const closing = { key: "global\u001fclosing", name: "closing", is_global: true,
    closing: true }
  const external = { key: "external\u001fnode\u001fowner", name: "owner",
    is_global: false, is_external: true }
  expect(model.paletteEntries("workspaces", current, [],
    [current, next, closing, external], [], "").map(entry => entry.workspace_key)).toEqual([
    current.key, next.key
  ])
  expect(model.paletteEntries("nodes", current, [], [], [
    { node_id: "node-a", alias: "local", workspace_owner_eligible: true },
    { node_id: "node-b", alias: "offline", workspace_owner_eligible: false }
  ], "node-a")).toEqual([expect.objectContaining({
    node_id: "node-a", selected: true, action: "select-node"
  })])
})

test("normalizes the exact qualified focused terminal", () => {
  expect(model.normalizeFocusedTerminal({
    revision: 42,
    shell: { node_id: "node-a", inner_id: "shell-a" }
  })).toEqual({ revision: 42, node_id: "node-a", shell_id: "shell-a" })
  expect(model.normalizeFocusedTerminal(null)).toBeNull()
  expect(() => model.normalizeFocusedTerminal({
    revision: 0,
    shell: { node_id: "node-a", inner_id: "shell-a" }
  })).toThrow()
})

test("normalizes bounded Boomux Web lifecycle state", () => {
  expect(model.normalizeWebStatus({ running: false, port: 3737 })).toEqual({
    running: false,
    port: 3737,
    tailscale: false,
    dashboard_url: "",
    opencode_url: ""
  })
  expect(model.normalizeWebStatus({
    running: true,
    port: 3737,
    tailscale: true,
    dashboard_url: "https://host.example.ts.net",
    opencode_url: "https://host.example.ts.net:4097"
  })).toEqual({
    running: true,
    port: 3737,
    tailscale: true,
    dashboard_url: "https://host.example.ts.net",
    opencode_url: "https://host.example.ts.net:4097"
  })
  expect(() => model.normalizeWebStatus({ port: 3737 })).toThrow()
})

test("keeps only available Agent hosts with current lifecycle assets", () => {
  expect(model.availableAgentHosts({ integrations: [
    { name: "opencode", display_name: "OpenCode",
      host: { state: "available", executable: "/bin/opencode" },
      asset: { state: "current" } },
    { name: "kiro", display_name: "Kiro CLI",
      host: { state: "available", executable: "/bin/kiro-cli" },
      asset: { state: "current" } },
    { name: "claude", display_name: "Claude Code",
      host: { state: "missing", executable: null }, asset: { state: "current" } },
    { name: "codex", display_name: "Codex",
      host: { state: "available", executable: "/bin/codex" },
      asset: { state: "missing" } }
  ] })).toEqual([
    { name: "opencode", label: "OpenCode", command: ["/bin/opencode"] },
    { name: "kiro", label: "Kiro CLI", command: ["/bin/kiro-cli"] }
  ])
})

test("discovers Agent hosts instead of hard-coding host buttons", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "integration", "status", "--json"]')
  expect(panel).toContain('label: "Select Agent"')
  expect(panel).not.toContain('text: "OpenCode"')
  expect(panel).not.toContain('text: "Pi"')
})

test("opens a keyboard-owned palette through plugin IPC", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("function palette(): void { root.togglePalette() }")
  expect(panel).toContain('text: "Palette"')
  expect(panel).toContain("onClicked: root.showPalette()")
  expect(panel).toContain("focusTarget: root.paletteOpen ? paletteSearchField : keyCatcher")
  expect(panel).toContain('showForm(entry.action === "create-shell" ? "shell" : "agent", targetNodeId, true)')
  expect(panel).toContain("function paletteItem(entry)")
  expect(panel).toContain("!openProcess.running && !executionOpenProcess.running")
  expect(panel).toContain("visible: !root.formFromPalette")
  expect(panel).toContain('setPaletteMode("agents")')
  expect(panel).toContain('setPaletteMode("shells")')
  expect(panel).toContain('setPaletteMode("launchers")')
  expect(panel).toContain('setPaletteMode("schedules")')
  expect(panel).toContain('selectSchedule(targetSchedule.key)')
  expect(panel).toContain("function paletteItemCanRemove(entry)")
  expect(panel).toContain("onClicked: root.requestRemoveItem(root.paletteItem(modelData))")
  expect(panel).toContain('entry.action === "remove-workspace"')
  expect(panel).not.toContain('action: "remove-schedule"')
  expect(panel).toContain("removeDialogKeyHandler.forceActiveFocus()")
  expect(panel).toContain("removeItemDialog.handleKey(event)")
  expect(panel).toContain('(activeTab === "schedules" || paletteOpen)')
  expect(panel).toContain('root.activeTab === "schedules" && root.selectedSchedule')
})

test("exits the palette and confirms Workspace and Node selections", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel.match(/closePaletteAfterSelection\(\)/g)).toHaveLength(4)
  expect(panel).toContain('showNotice("Creation Node", String(node.alias), nodeScreen, true)')
  expect(panel).toContain('showNotice("Default Workspace", active.name,')
  expect(panel).toContain('showNotice("Workspace selection failed", root.actionMessage,')
  expect(panel).toContain('WlrLayershell.namespace: "omarchy-boomux-notice"')
  expect(panel).toContain("if (Date.now() < noticeProtectedUntil) return")
  expect(panel).toContain('showNotice("Workspace opened", pending.name,')
  expect(panel).toContain('showNotice("Workspace open warning", pending.unavailablePlacements + " placement"')
  expect(panel).toContain('showNotice("Workspace open warning", root.actionMessage,')
  expect(panel).toContain('return "Active Workspace: " + String(focusedWorkspace.name)')
  expect(panel).toContain('return "Palette: " + String(selectedWorkspace.name) + addTarget')
})

test("keeps Tailscale Web lifecycle behind the Boomux CLI", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "web", "start", "--tailscale", "--json"]')
  expect(panel).toContain('["boomux", "web", "status", "--json"]')
  expect(panel).toContain('["boomux", "web", "stop", "--json"]')
  expect(panel).not.toContain('["tailscale"')
  expect(panel).not.toContain("root.webStartProcess")
  expect(panel).not.toContain("root.webStopProcess")
  expect(panel).toContain('text: "TAILNET WEB"')
  expect(panel).toContain('text: "Access agents through Tailnet."')
  expect(panel).toContain('root.webRunning ? "Open" : "Start Web"')
  expect(panel.indexOf('text: "TAILNET WEB"')).toBeLessThan(panel.indexOf('text: "AGENTS"'))
})

test("bounds passive update responses before collecting stdout", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel.match(/"--max-filesize", "65536"/g)).toHaveLength(2)
  expect(panel).not.toContain('"--location"')
})

test("uses Boomux events to refresh focused terminal state promptly", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "events", "--json"]')
  expect(panel).toContain('"focused_terminal_presentation_changed"')
  expect(panel).toContain("root.requestFocusedTerminalRefresh()")
})

test("persists the explicitly selected coordinator Workspace", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "workspace", "select", workspaceSelectionActive.id]')
  expect(panel).toContain('["boomux", "workspace", "clear"]')
  expect(panel).toContain('cliFeatures.indexOf("persistent_workspace_selection") >= 0')
  expect(panel).toContain('cliFeatures.indexOf("create_and_open_shell") >= 0')
  expect(panel).toContain('requestWorkspaceSelection(selectedWorkspace)')
  expect(panel).toContain('resolvePendingWorkspace(workspaces[p])')
})

test("offers explicit Workspace creation choices and one consistent action", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('text: "Create from Existing Project"')
  expect(panel).toContain('text: "Create New"')
  expect(panel).not.toContain('text: "Create from Project"')
  expect(panel).not.toContain('text: "Custom"')
  expect(panel).toContain('initialShell: globalWorkspacesAvailable')
  expect(panel).toContain('kind: "create-workspace-shell"')
})

test("preserves the Workspace item viewport across polling snapshots", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("var itemScrollY = itemList ? itemList.contentY : 0")
  expect(panel).toContain("restoreWorkspaceItemScroll(itemScrollY)")
  expect(panel).toContain("itemList.contentY = Math.max(0")
  expect(panel).toContain("if (signature === workspaceItemsSignature) return")
  expect(panel).toContain("onWorkspaceDetailChanged: syncWorkspaceItems()")
})

test("keeps guided Node setup feedback visible", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain(
    "omarchy-launch-tui --app-id=org.omarchy.boomux-node-add boomux __guided-node-add"
  )
})

test("refreshes the installed CLI version after an upgrade", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("onOpenedChanged: if (opened) {\n    refreshInstalledState()")
  expect(panel).toContain('if (text === "r" || text === "R") root.refreshInstalledState()')
})

test("keeps Create Node inside the Nodes surface", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('text: "NODES"')
  expect(panel).toContain('text: "Create Node"')
  expect(panel).toContain('root.activeTab === "nodes"')
})

test("creates coordinated Workspaces without the removed compound command", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).not.toContain("create-project")
})

describe("CLI envelope normalization", () => {
  test("parses protocol 38 into one task-first multi-placement Workspace", () => {
    const snapshot = normalized()
    const release = snapshot.workspaces.find(workspace => workspace.id === "global-1")
    expect(model.snapshotSupportsGlobalWorkspaces(snapshot.nodes)).toBe(true)
    expect(release.key).toBe("global\u001fglobal-1")
    expect(release.placements).toHaveLength(3)
    expect(release.shells.map(shell => [shell.node_id, shell.id])).toEqual([
      ["node-a", "resource-shared"], ["node-b", "resource-shared"]
    ])
    expect(release.schedules.map(schedule => schedule.workspace_name)).toEqual([
      "release", "release"
    ])
    expect(release.placements[1].default_cwd).toBe("/srv/release")
    expect(snapshot.nodes.map(node => [node.workspace_count, node.shell_count,
      node.agent_count, node.launcher_count, node.schedule_count])).toEqual([
      [1, 1, 1, 1, 1],
      [1, 1, 1, 1, 1],
      [0, 0, 0, 0, 0]
    ])
    const external = snapshot.workspaces.filter(workspace => workspace.is_external)
    expect(external).toHaveLength(2)
    expect(new Set(external.map(workspace => workspace.key)).size).toBe(2)
  })

  test("preserves duplicate inner resource IDs as qualified identities", () => {
    const snapshot = normalized()
    expect(new Set(snapshot.shells.map(shell => shell.key)).size).toBe(2)
    expect(new Set(snapshot.agents.map(agent => agent.key)).size).toBe(2)
    expect(new Set(snapshot.schedules.map(schedule => schedule.key)).size).toBe(2)
    const release = snapshot.workspaces.find(workspace => workspace.is_global)
    expect(new Set(release.launchers.map(launcher => launcher.key)).size).toBe(2)
    const localShell = snapshot.shells.find(shell => shell.node_id === "node-a")
    const remoteShell = snapshot.shells.find(shell => shell.node_id === "node-b")
    const localAgent = snapshot.agents.find(agent => agent.node_id === "node-a")
    const remoteAgent = snapshot.agents.find(agent => agent.node_id === "node-b")
    expect(model.agentMatchesShell(localAgent, localShell)).toBe(true)
    expect(model.agentMatchesShell(remoteAgent, remoteShell)).toBe(true)
    expect(model.agentMatchesShell(localAgent, remoteShell)).toBe(false)
    expect(model.agentMatchesShell(remoteAgent, localShell)).toBe(false)
    expect(model.acknowledgementIdentity(localAgent, 3).agentKey)
      .not.toBe(model.acknowledgementIdentity(remoteAgent, 3).agentKey)
    expect(snapshot.executions[0].schedule_key).toBe("node-b\u001fresource-shared")
  })

  test("rejects a relationship whose qualified Node does not match its projection", () => {
    const envelope = structuredClone(protocol38Envelope)
    envelope.data.nodes[1].remote_projection.agents[0].shell_id.node_id = "node-a"
    expect(() => normalized(envelope)).toThrow("invalid qualified Agent Shell ID")
  })

  test("falls back through the exact protocol 37 owner-local envelope", () => {
    const snapshot = normalized(protocol37Envelope)
    expect(protocol37Envelope.data.workspaces).toEqual([])
    expect(protocol37Envelope.data.external_workspaces).toEqual([])
    expect(model.snapshotSupportsGlobalWorkspaces(snapshot.nodes)).toBe(false)
    expect(snapshot.workspaces).toHaveLength(1)
    expect(snapshot.workspaces[0].key).toBe("local-node\u001flegacy-workspace")
    expect(snapshot.workspaces[0].coordination).toBe("legacy")
    expect(model.workspaceCreationBlockReason(snapshot.workspaces[0], 0)).toBe("")
    expect(model.shellCreateCommand(snapshot.workspaces[0], "shell", "/tmp/legacy",
      "local-node", [])).toEqual([
      "boomux", "shell", "create", "legacy-workspace", "--name", "shell",
      "--cwd", "/tmp/legacy"
    ])
  })

  test("qualifies legacy workspace.inspect resources with the enclosing Node", () => {
    const snapshot = normalized(protocol37Envelope)
    const workspace = snapshot.workspaces[0]
    const node = snapshot.nodes[0]
    const detail = model.normalizeWorkspaceDetail({
      id: "legacy-workspace",
      name: "legacy",
      shells: [{ id: "shared", workspace_id: "legacy-workspace", name: "shell",
        cwd: "/tmp/legacy", owner: "user", status: "running", run: { id: "run" } }],
      launchers: [{ id: "shared", workspace_id: "legacy-workspace", name: "launch",
        cwd: "/tmp/legacy", command: ["printf", "%s", "safe"] }],
      agents: [{ id: "agent", workspace_id: "legacy-workspace", shell_id: "shared",
        run_id: "run", name: "agent", integration: "opencode",
        observation: { revision: 1, state: "working", observed_at_ms: 1 } }],
      schedules: []
    }, workspace, node)
    expect(detail.shells[0].key).toBe("local-node\u001fshared")
    expect(detail.launchers[0].key).toBe("local-node\u001fshared")
    expect(detail.agents[0].shell_key).toBe("local-node\u001fshared")
    expect(detail.shells[0].owner_workspace_id).toBe("legacy-workspace")
    expect(detail.shells[0].placement_state).toBe("active")
    expect(model.agentMatchesShell(detail.agents[0], detail.shells[0])).toBe(true)
    expect(model.resourceActionable(detail.shells[0], true)).toBe(true)
  })
})

describe("qualified commands and action gates", () => {
  test("keeps --node for a local external Workspace that collides with a global ID", () => {
    const snapshot = normalized()
    const global = snapshot.workspaces.find(workspace => workspace.is_global)
    const localExternal = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-a")
    expect(global.id).toBe("global-1")
    expect(localExternal.name).toBe("global-1")
    expect(localExternal.node_local).toBe(true)
    expect(model.workspaceCreationBlockReason(localExternal, 2)).toContain("Adopt or link")
    expect(model.workspaceOpenCommand(global)).toEqual([
      "boomux", "workspace", "open", "global-1"
    ])
    expect(model.workspaceOpenCommand(localExternal)).toEqual([
      "boomux", "workspace", "open", "global-1", "--node", "node-a"
    ])
    expect(model.workspaceCloseCommand(global)).toEqual([
      "boomux", "workspace", "close", "global-1"
    ])
  })

  test("keeps unavailable and close-pending placement resources disabled", () => {
    expect(model.resourceActionable({ placement_state: "unavailable" }, true)).toBe(false)
    expect(model.resourceActionable({ placement_state: "close_pending" }, true)).toBe(false)
    expect(model.resourceActionable({ placement_state: "active" }, true)).toBe(true)
    const closing = { is_global: true, closing: true }
    expect(model.workspaceCreationBlockReason(closing, 2)).toContain("closing")
    const envelope = structuredClone(protocol38Envelope)
    envelope.data.workspaces[0].closing = true
    envelope.data.workspaces[0].placements[1].state = "close_pending"
    const remoteShell = normalized(envelope).shells.find(shell => shell.node_id === "node-b")
    const remoteAgent = normalized(envelope).agents.find(agent => agent.node_id === "node-b")
    expect(remoteShell.placement_state).toBe("close_pending")
    expect(model.resourceActionable(remoteShell, true)).toBe(false)
    expect(model.agentOpenTarget(remoteAgent, [remoteShell], true)).toBeNull()
    expect(model.agentOpenTarget(Object.assign({}, remoteAgent, { placement_state: "active" }),
      [Object.assign({}, remoteShell, { placement_state: "active" })], true)).not.toBeNull()
  })

  test("creates coordinated Workspace metadata without assigning a Node or path", () => {
    expect(model.workspaceCreateCommand("release; rm -rf /", "/tmp/$(false)", true))
      .toEqual(["boomux", "workspace", "create", "release; rm -rf /"])
    expect(model.workspaceCreateCommand("legacy", "/tmp/legacy", false)).toEqual([
      "boomux", "workspace", "create", "legacy", "--cwd", "/tmp/legacy"
    ])
    expect(model.initialWorkspaceShellCommand(
      { id: "global-1" }, "/tmp/project", "node-a")).toEqual([
      "boomux", "shell", "create", "global-1", "--node", "node-a",
      "--cwd", "/tmp/project"
    ])
    expect(model.defaultCreationNodeId(protocol38Envelope.data.nodes)).toBe("node-a")
    expect(model.defaultCreationNodeId([protocol38Envelope.data.nodes[1]])).toBe("node-b")
    expect(model.defaultCreationNodeId(protocol38Envelope.data.nodes.map(node =>
      Object.assign({}, node, { local: false })))).toBe("")
    expect(model.qualifiedCommand(["boomux", "open"], "shell;$(false)", "node-b", false))
      .toEqual(["boomux", "open", "shell;$(false)", "--node", "node-b"])
  })

  test("qualifies external Shell and Agent creation for local and remote owners", () => {
    const snapshot = normalized()
    const local = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-a")
    const remote = snapshot.workspaces.find(workspace => workspace.is_external
      && workspace.node_id === "node-b")
    expect(model.shellCreateCommand(local, "agent", "/tmp/local", "node-a", ["opencode"]))
      .toEqual(["boomux", "shell", "create", "global-1", "--name", "agent",
        "--cwd", "/tmp/local", "--node", "node-a", "--", "opencode"])
    expect(model.shellCreateCommand(remote, "shell", "/tmp/remote", "node-b", []))
      .toEqual(["boomux", "shell", "create", "external-b", "--name", "shell",
        "--cwd", "/tmp/remote", "--node", "node-b"])
  })
})

describe("request identity", () => {
  test("retains the selected exact run until its focused refresh replaces it", () => {
    const current = [
      { id: "exact-local", schedule_key: "node-a\u001fschedule" },
      { id: "old-remote", schedule_key: "node-b\u001fother" }
    ]
    const snapshot = [
      { id: "stale-selected", schedule_key: "node-a\u001fschedule" },
      { id: "fresh-remote", schedule_key: "node-b\u001fother" }
    ]

    expect(model.mergeSnapshotExecutions(current, snapshot,
      "node-a\u001fschedule")).toEqual([
      { id: "fresh-remote", schedule_key: "node-b\u001fother" },
      { id: "exact-local", schedule_key: "node-a\u001fschedule" }
    ])
    expect(model.mergeSnapshotExecutions(current, snapshot, "")).toBe(snapshot)
  })

  test("queues project discovery for the latest rapidly selected Node", () => {
    const requested = model.projectDiscoveryIdentity("node-b")
    const active = model.projectDiscoveryIdentity("node-a")
    expect(model.projectDiscoveryResponseCurrent(requested, active, "node-b")).toBe(false)
    expect(model.projectDiscoveryCommand(protocol38Envelope.data.nodes[1])).toEqual([
      "boomux", "project", "list", "--json", "--node", "node-b"
    ])
    expect(model.projectDiscoveryResponseCurrent(requested, requested, "node-b")).toBe(true)
  })

  test("keys suggestions by global Workspace, Node, and equal owner Workspace ID", () => {
    const local = model.suggestionIdentity("global\u001fglobal-1", "node-a", "owner-shared")
    const remote = model.suggestionIdentity("global\u001fglobal-1", "node-b", "owner-shared")
    expect(local.key).not.toBe(remote.key)
    expect(model.suggestionResponseMatches({ node_id: "node-a", workspace_id: "owner-shared" },
      local, true, true)).toBe(true)
    expect(model.suggestionResponseMatches({ workspace_id: "owner-shared" },
      local, true, true)).toBe(false)
    expect(model.suggestionResponseMatches({ node_id: "node-b", workspace_id: "owner-shared" },
      remote, false)).toBe(true)
    expect(model.suggestionResponseMatches({ node_id: "node-a", workspace_id: "owner-shared" },
      remote, false)).toBe(false)
  })

  test("resolves a deferred Agent Shell once by exact Workspace and Node", () => {
    const snapshot = normalized()
    const pending = { workspaceKey: "global\u001fglobal-1", nodeId: "node-b",
      name: "tests", armed: true }
    const resolved = model.resolvePendingShell(pending, snapshot.workspaces)
    expect(resolved.identity).toEqual({
      workspaceKey: "global\u001fglobal-1",
      nodeId: "node-b",
      shellId: "resource-shared",
      runId: "run-shared"
    })
    expect(model.resolvePendingShell(null, snapshot.workspaces)).toBeNull()
    expect(model.resolvePendingShell(Object.assign({}, pending, { nodeId: "node-a" }),
      snapshot.workspaces)).toBeNull()
    const consumed = model.consumePendingShell(pending, snapshot.workspaces)
    expect(consumed.pending).toBeNull()
    expect(model.consumePendingShell(consumed.pending, snapshot.workspaces).resolved).toBeNull()
  })
})
