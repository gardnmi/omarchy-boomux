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
  expect(model.versionDirection("0.29.1", "0.30.1")).toBe("older")
  expect(model.versionDirection("0.31.0", "0.30.1")).toBe("newer")
  expect(model.versionDirection("v0.30.1", "0.30.1")).toBe("current")
  expect(model.versionDirection("main", "0.30.1")).toBe("unknown")
})

test("recognizes only canonical Boomux special Workspace names", () => {
  expect(model.boomuxSpecialWorkspaceId(
    "special:boomux-a84eb9a6-9611-478b-bb7d-d18e40d44d9c"
  )).toBe("a84eb9a6-9611-478b-bb7d-d18e40d44d9c")
  expect(model.boomuxSpecialWorkspaceId(
    "special:boomux-018f9f63-7b2c-7d00-8000-0123456789ab"
  )).toBe("018f9f63-7b2c-7d00-8000-0123456789ab")
  for (const invalid of [
    "special:scratchpad",
    "special:boomux-not-an-id",
    "special:boomux-A84EB9A6-9611-478b-bb7d-d18e40d44d9c",
    "boomux-a84eb9a6-9611-478b-bb7d-d18e40d44d9c"
  ]) expect(model.boomuxSpecialWorkspaceId(invalid)).toBe("")
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

test("marks only an Agent backed by the exact focused Shell", () => {
  expect(model.agentFocused({ shell_key: "node-a\u001fshell" }, "node-a\u001fshell")).toBe(true)
  expect(model.agentFocused({ shell_key: "node-b\u001fshell" }, "node-a\u001fshell")).toBe(false)
  expect(model.agentFocused({ shell_key: "node-a\u001fshell" }, "")).toBe(false)
})

test("keeps mixed-version private runner Shells and Agents out of user views", () => {
  const shells = [
    { id: "private-object", node_id: "node-a", owner: { kind: "schedule" } },
    { id: "private-string", node_id: "node-a", owner: "schedule" },
    { id: "private-object", node_id: "node-b", owner: { kind: "user" } }
  ]
  expect(model.agentHasPrivateOwner(
    { node_id: "node-a", shell_id: "private-object" }, shells)).toBe(true)
  expect(model.agentHasPrivateOwner(
    { node_id: "node-a", shell_id: "private-string" }, shells)).toBe(true)
  expect(model.agentHasPrivateOwner(
    { node_id: "node-b", shell_id: "private-object" }, shells)).toBe(false)

  const items = model.workspaceTreeItems({
    shells: [
      { id: "shell", key: "node\u001fshell", node_id: "node", node_alias: "local",
        name: "terminal", owner: "user", status: "running", cwd: "/tmp" },
      { id: "command", node_id: "node", node_alias: "local", name: "server",
        owner: "user", status: { exited: 2 }, command: ["bun", "run", "dev"] },
      { id: "private", node_id: "node", name: "private", owner: { kind: "schedule" },
        status: "running" }
    ],
    launchers: [{ id: "launcher", node_id: "node", node_alias: "local", name: "browser",
      command: ["xdg-open", "https://example.com"] }]
  })
  expect(items.map(item => [item.kind, item.name, item.status])).toEqual([
    ["shell", "terminal", "running"],
    ["command", "server", "exited"],
    ["launcher", "browser", "on open"]
  ])
  expect(items[1].detail).toBe("bun run dev")
  expect(items[0].workspace.shells).toHaveLength(3)
  expect(items[2].launcher.id).toBe("launcher")
  expect(items[2]).toEqual(expect.objectContaining({
    id: "launcher", node_id: "node", node_local: false
  }))
})

test("marks only the exact qualified terminal-backed Workspace tree item focused", () => {
  const focusedKey = "node-a\u001fshell"
  const shell = { key: focusedKey, kind: "shell", shell: { id: "shell" } }
  const sameIdOtherNode = {
    key: "node-b\u001fshell", kind: "shell", shell: { id: "shell" }
  }
  const launcherCollision = {
    key: focusedKey, kind: "launcher", shell: null, launcher: { id: "shell" }
  }

  expect(model.workspaceTreeItemFocused(shell, focusedKey)).toBe(true)
  expect(model.workspaceTreeItemFocused(sameIdOtherNode, focusedKey)).toBe(false)
  expect(model.workspaceTreeItemFocused(launcherCollision, focusedKey)).toBe(false)
  expect(model.workspaceTreeItemFocused(shell, "")).toBe(false)
})

test("keeps the Workspace tree model stable across lifecycle-only refreshes", () => {
  const workspace = {
    key: "global:workspace", id: "workspace", name: "boomux", is_global: true,
    shells: [{ key: "node\u001fshell", id: "shell", name: "terminal", owner: "user",
      status: "running", node_id: "node", node_alias: "local" }],
    agents: [{ observation: { observed_at_ms: 100 } }]
  }
  const first = model.workspaceTreeModelSignature([workspace])
  workspace.agents[0].observation.observed_at_ms = 200
  expect(model.workspaceTreeModelSignature([workspace])).toBe(first)
  workspace.shells[0].status = { exited: 0 }
  expect(model.workspaceTreeModelSignature([workspace])).not.toBe(first)
})

test("formats compact relative Agent update times", () => {
  const now = 1_000_000_000
  expect(model.relativeTime(now - 20_000, now)).toBe("now")
  expect(model.relativeTime(now - 5 * 60_000, now)).toBe("5m ago")
  expect(model.relativeTime(now - 2 * 60 * 60_000, now)).toBe("2h ago")
  expect(model.relativeTime(now - 3 * 24 * 60 * 60_000, now)).toBe("3d ago")
  expect(model.relativeTime(0, now)).toBe("unknown")
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

test("opens pane settings and the Boomux config editor", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('tooltipText: "Open Boomux settings"')
  expect(panel).toContain("onClicked: root.showSettings()")
  expect(panel).toContain("function persistPaneSettings(values)")
  expect(panel).toContain("bar.shell.updateEntryInline(moduleName, next)")
  expect(panel).toContain('root.persistPaneSettings({ side: "left" })')
  expect(panel).toContain('root.persistPaneSettings({ side: "right" })')
  expect(panel).toContain("paneWidth: root.paneWidth - 20")
  expect(panel).toContain("paneWidth: root.paneWidth + 20")
  expect(panel).toContain("omarchy-launch-tui --app-id=org.omarchy.boomux-config boomux config edit")
  expect(panel).toContain("Qt.callLater(function() { settingsBackButton.forceActiveFocus() })")
  expect(panel).toContain("KeyNavigation.tab: settingsLeftButton")
  expect(panel).not.toMatch(/palette/i)
  expect(panel).toContain("removeDialogKeyHandler.forceActiveFocus()")
  expect(panel).toContain("removeItemDialog.handleKey(event)")
  expect(panel).not.toContain('root.activeTab === "schedules"')
})

test("shows the installed Boomux CLI version in the pane header", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: boomuxHeaderTitle")
  expect(panel).toContain('(root.cliVersion !== "" ? "v" + root.cliVersion + " · " : "")')
})

test("shows one flat Agent list ordered by latest update", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("readonly property var paneAgents: visibleAgents")
  expect(panel).toContain("Math.min(contentHeight, Style.space(700))")
  expect(panel).not.toContain("panel.height - workspaceTreeColumn.implicitHeight")
  expect(panel).not.toContain('section.property: "workspace_name"')
  expect(panel).not.toContain("WorkspaceModel.agentsByWorkspace")
})

test("keeps removed-shell attention dismissal explicit", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const openAgent = panel.slice(panel.indexOf("function openAgent"),
    panel.indexOf("function agentShellRetained"))
  expect(openAgent).not.toContain("acknowledgeAgent(agent)")
  expect(openAgent).toContain("use Dismiss to acknowledge its notification")
  expect(panel).toContain("readonly property bool openable:")
  expect(panel).toContain("enabled: agentRow.openable")
})

test("bounds main and settings content with fallback scrolling", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: settingsScroll")
  expect(panel).toContain("contentHeight: settingsColumn.implicitHeight")
  expect(panel).toContain("id: contentScroll")
  expect(panel).toContain("contentHeight: contentColumn.implicitHeight")
})

test("delegates local updates to the capability-gated Boomux flow", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('data.json_commands.indexOf("update.status") >= 0')
  expect(panel).toContain('cliFeatures.indexOf("guided_local_update") >= 0')
  expect(panel).toContain('command: ["boomux", "update", "status", "--json"]')
  expect(panel).toContain("WorkspaceModel.guidedLocalUpdateCommand()")
  expect(panel).toContain('boomuxUpdateAction !== "run_update"')
  expect(panel).toContain("Guided Boomux update opened")
  expect(panel).toContain("Complete the update in the terminal, then press R to refresh the pane.")
  expect(panel).toContain("Update with the AUR or package helper that installed Boomux.")
  expect(panel).not.toContain('root.actionMessage = "Boomux update finished"')
  expect(panel).not.toContain('localUpdateProcess.command = ["curl"')
  expect(model.guidedLocalUpdateCommand()).toEqual([
    "omarchy-launch-tui", "--app-id=org.omarchy.boomux-update", "boomux", "update"
  ])
})

test("creates active-Workspace Shells from remote Node action menus", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("visibleNodes: nodes.filter(function(node) { return !node.local })")
  expect(panel).toContain('text: "Create Shell"')
  expect(panel).toContain('root.runActionMenuAction("shell")')
  expect(panel).toContain('root.runActionMenuAction("remove")')
  expect(panel).toContain("createShellOnNode(target.node)")
  expect(panel).toContain("requestForgetNode(target.node)")
  expect(panel).toContain('["boomux", "node", "forget",')
  expect(panel).toContain("It does not contact the Node or stop its processes.")
  expect(panel).toContain("String(activeBoomuxWorkspaceId), \"--node\", String(node.node_id), \"--open\"")
  expect(panel).toContain('"Remote Node: " + String(root.creationNode.alias)')
  expect(panel).not.toContain("defaultNodeId")
})

test("offers exact guided updates only for older capable remote Nodes", () => {
  const features = ["observed_node_helper_version", "node_upgrade_coordination"]
  const remote = {
    node_id: "node;$(false)", local: false, observed_helper_version: "0.29.1",
    observed_capabilities: features
  }
  expect(model.nodeCanUpgrade(remote, "0.30.1", features)).toBe(true)
  const qmlFeatures = {
    0: "observed_node_helper_version", 1: "node_upgrade_coordination", length: 2
  }
  expect(model.nodeCanUpgrade(Object.assign({}, remote,
    { observed_capabilities: qmlFeatures }), "0.30.1", qmlFeatures)).toBe(true)
  expect(model.nodeCanUpgrade(Object.assign({}, remote,
    { stale: true, current: false, health: "authentication_required" }),
    "0.30.1", features)).toBe(true)
  expect(model.guidedNodeUpgradeCommand(remote.node_id)).toEqual([
    "omarchy-launch-tui", "--app-id=org.omarchy.boomux-node-upgrade",
    "boomux", "__guided-node-upgrade", "node;$(false)"
  ])
  expect(model.nodeCanUpgrade(Object.assign({}, remote,
    { observed_helper_version: "0.30.1" }), "0.30.1", features)).toBe(false)
  expect(model.nodeCanUpgrade(Object.assign({}, remote,
    { observed_helper_version: "0.31.0" }), "0.30.1", features)).toBe(false)
  expect(model.nodeCanUpgrade(Object.assign({}, remote,
    { observed_helper_version: "" }), "0.30.1", features)).toBe(false)
  expect(model.nodeCanUpgrade(remote, "0.30.1", ["node_upgrade_coordination"])).toBe(false)

  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("root.nodeCanUpgrade(root.actionMenuTarget.node)")
  expect(panel).toContain("WorkspaceModel.guidedNodeUpgradeCommand(node.node_id)")
  expect(panel).toContain("Update Boomux on this control machine before managing the Node.")
  expect(panel).toContain("cached data retained · retrying automatically")
})

test("offers exact guided reauthentication only for authentication-required Nodes", () => {
  const features = ["node_reauthentication"]
  const remote = {
    node_id: "node;$(false)", local: false, health: "authentication_required"
  }
  expect(model.nodeCanReauthenticate(remote, features, 38)).toBe(true)
  expect(model.nodeCanReauthenticate(Object.assign({}, remote,
    { health: "unreachable" }), features, 38)).toBe(false)
  expect(model.nodeCanReauthenticate(Object.assign({}, remote,
    { local: true }), features, 38)).toBe(false)
  expect(model.nodeCanReauthenticate(remote, [], 38)).toBe(false)
  expect(model.nodeCanReauthenticate(remote, features, 37)).toBe(false)
  expect(model.guidedNodeReauthenticateCommand(remote.node_id)).toEqual([
    "omarchy-launch-tui", "--app-id=org.omarchy.boomux-node-reauthenticate",
    "boomux", "__guided-node-reauthenticate", "node;$(false)"
  ])

  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("root.nodeCanReauthenticate(root.actionMenuTarget.node)")
  expect(panel).toContain("WorkspaceModel.guidedNodeReauthenticateCommand(node.node_id)")
  expect(panel).toContain('text: "Authenticate"')
})

test("keeps the Nodes surface compact and reveals only exceptional details", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: nodeMenuButton")
  expect(panel).toContain('tooltipText: root.nodeCanReauthenticate(modelData)')
  expect(panel).toContain('" · action: Authenticate"')
  expect(panel).toContain('" · action: Update"')
  expect(panel).toContain("root.nodeHealthLabel(modelData) + \" · \"")
  expect(panel).toContain("text: root.nodeRuntimeSummary(root.selectedNode)")
  expect(panel).toContain("text: root.nodeWorkloadSummary(root.selectedNode)")
  expect(panel).toContain('root.selectedNode.health !== "online"')
  expect(panel).not.toContain('text: "ACTION"')
  expect(panel).not.toContain('text: "VERSION"')
  expect(panel).not.toContain('" · registration revision "')
  expect(panel).not.toContain('text: root.selectedNode ? "ID: "')
})

test("uses a configurable sliding side pane with an active Workspace tree", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const sidePane = fs.readFileSync(new URL("../SidePane.qml", import.meta.url), "utf8")
  expect(panel).toContain('String(setting("side", "left"))')
  expect(panel).toContain('Number(setting("paneWidth", Style.space(360)))')
  expect(panel).toContain("SidePane {")
  expect(panel).not.toContain('workspaceTreeDelegate.workspaceActive ? "ACTIVE"')
  expect(panel).toContain("modelData.id === root.activeBoomuxWorkspaceId")
  expect(panel).toContain("root.selectedWorkspaceIndex = workspaceTreeDelegate.index")
  expect(panel).toContain("root.toggleWorkspaceExpansion(workspaceTreeDelegate.modelData)")
  expect(panel).toContain("workspaceTreeList.positionViewAtIndex(index, ListView.Beginning)")
  expect(panel).not.toContain("onActiveBoomuxTerminalKeyChanged")
  expect(panel).not.toContain("function positionFocusedWorkspace")
  expect(panel).not.toContain("onActiveBoomuxWorkspaceIdChanged")
  expect(panel).toContain("workspacePositionTimer.restart()")
  expect(panel).toContain("interval: 180")
  expect(panel).toContain("root.applyWorkspacePosition(workspaceKey)")
  expect(panel).toContain("height: root.workspaceTreeHeight")
  expect(panel).toContain("property int workspaceTreeHeight: Style.space(340)")
  expect(panel).toContain("cursorShape: Qt.SizeVerCursor")
  expect(panel).toContain("root.setWorkspaceTreeHeight(startingHeight + translation.y)")
  expect(panel).toContain("workspaceDelegate.revealTreeItem(root.selectedWorkspaceItemIndex)")
  expect(panel).toContain("id: treeItemRepeater")
  expect(panel).not.toContain("else if (root.expandedWorkspaceKey !== \"\")")
  expect(panel).not.toContain("setWorkspaceTreeHeight(workspaceTreeHeight)")
  expect(panel).toContain("panel.height - Style.space(260)")
  expect(panel).not.toContain("workspaceTreeList.positionViewAtIndex(index, ListView.Contain)")
  expect(panel).toContain("onClicked: root.activateWorkspaceRow(workspaceTreeDelegate.modelData)")
  const activation = panel.slice(panel.indexOf("function activateWorkspaceRow"),
    panel.indexOf("function openWorkspaceTreeItem"))
  expect(activation).not.toContain("close()")
  expect(activation).not.toContain("positionWorkspace(")
  expect(activation).toContain("expandedWorkspaceKey = workspace.key")
  expect(activation).toContain("pendingWorkspaceOpen = { key: workspace.key")
  expect(activation).toContain("function startPendingWorkspaceOpen()")
  expect(activation).toContain("openWorkspace(workspace, screen, presentationOnly)")
  expect(activation).toContain('cliFeatures.indexOf("desktop_workspace_show") >= 0')
  expect(activation).toContain("if (!presentationOnly) requestWorkspaceSelection(workspace)")
  expect(panel).toContain("root.startPendingWorkspaceOpen()")
  expect(panel).not.toContain("&& !actionProcess.running\n                  cursorShape")
  expect(panel).toContain('var tabs = ["agents", "nodes"]')
  expect(panel).toContain('else if (text === "2") root.selectTab("nodes")')
  expect(panel).not.toContain('root.selectTab("schedules")')
  expect(panel).not.toContain('text === "3"')
  expect(panel).toContain('width: (parent.width - parent.spacing) / 2')
  expect(panel).not.toContain("Enter opens · D dismisses · Tab switches · R refreshes")
  expect(panel).not.toContain("Up/Down selects · A creates a Node · Tab switches · R refreshes")
  expect(panel).toContain('visible: root.actionMessage !== ""')
  expect(panel).toContain("id: actionStatusText")
  expect(panel).toContain("anchors.bottom: parent.bottom")
  expect(panel).not.toContain('root.actionMessage = "Workspace shown"')
  expect(sidePane).toContain('WlrLayershell.namespace: "omarchy-boomux-side-pane"')
  expect(sidePane).toContain('WlrLayershell.namespace: "omarchy-boomux-side-pane-reservation"')
  expect(sidePane).toContain("exclusiveZone: implicitWidth")
  expect(sidePane).toContain("left: !root.onRight")
  expect(sidePane).toContain("right: root.onRight")
  expect(sidePane).toContain("mask: Region { item: card }")
  expect(sidePane).not.toContain("id: dismissArea")
  expect(sidePane).not.toContain("omarchy-boomux-side-pane-dismiss")
  expect(sidePane).not.toContain("requestPopout")
  expect(sidePane).not.toContain("releasePopout")
  expect(sidePane).not.toContain("popoutSwitching")
  expect(sidePane).toContain("Behavior on revealProgress")
  expect(sidePane).toContain('readonly property real paneX: onRight')
  expect(sidePane).toContain("readonly property real availablePaneWidth: Math.max(0,")
  expect(sidePane).toContain("width: root.effectivePaneWidth")
  expect(sidePane).toContain("height: root.availablePaneHeight")
})

test("provides full pane and action-menu keyboard navigation", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('property string focusSection: "workspaces"')
  expect(panel).toContain("function cycleFocusSection(direction)")
  expect(panel).toContain("function movePanelCursor(dx, dy)")
  expect(panel).toContain("function activatePanelCursor()")
  expect(panel).toContain("function showCursorActionMenu()")
  expect(panel).toContain("function moveActionMenu(offset)")
  expect(panel).toContain('else if (text === "m" || text === "M") root.showCursorActionMenu()')
  expect(panel).toContain('hasCursor: root.currentActionMenuAction === "rename"')
})

test("keeps the pane open after an Agent or Shell terminal opens", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const completion = panel.slice(panel.indexOf("id: openProcess"),
    panel.indexOf("id: acknowledgeProcess"))
  expect(completion).toContain('root.actionMessage = ""')
  expect(completion).not.toContain("root.close()")
})

test("does not expose scheduled work UI, polling, or commands", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const manifest = require("../manifest.json")
  const snapshot = normalized()
  expect(panel).not.toMatch(/scheduleListProcess|executionListProcess|executionOpenProcess/)
  expect(panel).not.toMatch(/\["boomux", "schedule"|\["boomux", "execution"/)
  expect(panel).not.toContain('text: "Schedules"')
  expect(panel).not.toContain("LAST 10 RUNS")
  expect("schedules" in snapshot).toBe(false)
  expect("executions" in snapshot).toBe(false)
  expect(manifest.version).toBe("2.0.0")
  expect(manifest.barWidget.aliases).not.toContain("schedule")
})

test("offers confirmed local Shell closure from the Workspace action menu", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('text: "⋮"')
  expect(panel).toContain('? "Remove Launcher" : "Close Shell"')
  expect(panel).toContain('onClicked: root.runActionMenuAction("remove")')
  expect(panel).toContain('return "Close Shell " + String(item.name)')
  expect(panel).toContain('String(item.shell.owner_workspace_id || owningWorkspace.id)')
  expect(panel).toContain('root.actionMessage = "Shell closed"')
  expect(panel).toContain('return "Close"')
})

test("keeps Workspace and item actions reachable from three-dot menus", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: workspaceHeaderActions")
  expect(panel).toContain("id: workspaceMenuButton")
  expect(panel).toContain("id: treeItemMenuButton")
  expect(panel).toContain('tooltipText: "Workspace actions"')
  expect(panel).toContain('tooltipText: "Item actions"')
  const tree = panel.slice(panel.indexOf("id: workspaceTreeList"),
    panel.indexOf("id: workspaceResizeHandle"))
  expect(tree).not.toContain("Start Agent in this Workspace")
  expect(tree).not.toContain('iconText: ""')
  expect(tree).not.toContain('text: modelData.kind === "launcher" ? "Remove" : "Close"')
  expect(panel).toContain('onClicked: root.runActionMenuAction("rename")')
  expect(panel).toContain('["boomux", "workspace", "rename"')
  expect(panel).toContain('["boomux", "launcher", "rename"')
  expect(panel).toContain('["boomux", "shell", "rename"')
  expect(panel).not.toContain('root.runActionMenuAction("open")')
  expect(panel).not.toContain('root.runActionMenuAction("agent")')
  expect(panel).not.toContain('text: "Start Agent"')
})

test("uses the existing exact launcher path from the Workspace tree", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('if (item.kind === "launcher") openWorkspaceItem(item)')
  expect(panel).not.toContain("invokeLauncher(")
  expect(panel).toContain('["boomux", "launcher", "invoke"]')
  expect(panel).toContain("item.id, item.node_id, owner && owner.local")
})

test("shows passive Workspace notices", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('WlrLayershell.namespace: "omarchy-boomux-notice"')
  expect(panel).toContain("if (Date.now() < noticeProtectedUntil) return")
  expect(panel).toContain('showNotice("Workspace opened", pending.name,')
  expect(panel).toContain('showNotice("Workspace open warning", pending.unavailablePlacements + " placement"')
  expect(panel).toContain('showNotice("Workspace open warning", root.actionMessage,')
  expect(panel).toContain("function showActionFailure(title, detail)")
  expect(panel).toContain('root.showActionFailure("Workspace selection failed"')
  expect(panel).toContain('root.showNotice("Boomux action failed", root.actionMessage,')
  expect(panel).toContain('root.showActionFailure("Terminal open failed"')
})

test("documents actual keyboard navigation and configuration mutation", () => {
  const readme = fs.readFileSync(new URL("../README.md", import.meta.url), "utf8")
  expect(readme).toContain("Switch Agents and Nodes")
  expect(readme).not.toContain("Schedules")
  expect(readme).toContain("Omarchy stores pane settings in `~/.config/omarchy/shell.json`")
  expect(readme).not.toContain("does not modify Boomux or Omarchy configuration directly")
})

test("keeps Tailscale Web lifecycle behind the Boomux CLI", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "web", "start", "--tailscale", "--json"]')
  expect(panel).toContain('["boomux", "web", "status", "--json"]')
  expect(panel).toContain('["boomux", "web", "stop", "--json"]')
  expect(panel).not.toContain('["tailscale"')
  expect(panel).not.toContain("root.webStartProcess")
  expect(panel).not.toContain("root.webStopProcess")
  expect(panel).toContain('text: "Tailnet Web · "')
  expect(panel).toContain('root.webRunning ? "Open" : "Start Web"')
  expect(panel.indexOf('text: "Tailnet Web · "')).toBeLessThan(panel.indexOf('text: "AGENTS"'))
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

test("shows the active Boomux special Workspace name in the bar", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("import Quickshell.Hyprland")
  expect(panel).toContain('name === "activespecialv2"')
  expect(panel).toContain('command: ["hyprctl", "-j", "monitors"]')
  expect(panel).toContain("WorkspaceModel.boomuxSpecialWorkspaceId")
  expect(panel).toContain("activeBoomuxWorkspaceName")
  expect(panel).toContain("openWorkspacePanel(root.activeBoomuxWorkspace)")
  expect(panel).toContain("openWorkspacePanel(root.activeBoomuxTerminalWorkspace)")
  expect(panel).not.toContain('"boomux", "workspace", "current"')
})

test("requests full Workspace restore in the owning desktop layer", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('cliFeatures.indexOf("workspace_open_desktop_show") >= 0')
  expect(model.workspaceOpenCommand({ id: "workspace-1", is_global: true }, true)).toEqual([
    "boomux", "workspace", "open", "workspace-1", "--show"
  ])
  expect(model.workspaceOpenCommand(
    { id: "workspace-1", is_global: true }, true, true
  )).toEqual(["boomux", "desktop", "show", "workspace-1"])
})

test("recognizes focused marked and legacy Boomux terminal windows", () => {
  const nodeId = "11111111-1111-4111-8111-111111111111"
  const shellId = "22222222-2222-4222-8222-222222222222"
  const key = `${nodeId}\u001f${shellId}`
  const shells = [{ key, name: "agent_boom", workspace_name: "boomux",
    node_local: true, node_alias: "local" }]

  expect(model.boomuxShellWindowKey(
    `boomux:shell:${nodeId}:${shellId} | boomux - agent_boom`, "", [])).toBe(key)
  expect(model.boomuxShellWindowKey("boomux - agent_boom", key, shells)).toBe(key)
  expect(model.boomuxShellWindowKey("Documentation", key, shells)).toBe("")
})

test("opens a Shell in its exact coordinated desktop Workspace", () => {
  const shell = { id: "shell-1", node_id: "node-1" }
  const workspace = { id: "workspace-1", is_global: true }
  expect(model.shellOpenCommand(shell, workspace, true)).toEqual([
    "boomux", "open", "shell-1", "--takeover", "--workspace", "workspace-1"
  ])
  expect(model.shellOpenCommand(shell, { id: "external-1", is_global: false }, false)).toEqual([
    "boomux", "open", "shell-1", "--node", "node-1", "--takeover"
  ])
})

test("shows focused Shell identity separately from the presented Workspace", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('command: ["hyprctl", "-j", "activewindow"]')
  expect(panel).toContain("activeBoomuxTerminalLabel")
  expect(panel).toContain('name === "activewindowv2"')
  expect(panel).toContain('"> " + String(activeBoomuxTerminalWorkspace.name) + " / " + shellName')
})

test("persists the explicitly selected coordinator Workspace", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('["boomux", "workspace", "select", workspaceSelectionActive.id]')
  expect(panel).toContain('["boomux", "workspace", "clear"]')
  expect(panel).toContain('cliFeatures.indexOf("persistent_workspace_selection") >= 0')
  expect(panel).toContain('cliFeatures.indexOf("create_and_open_shell") >= 0')
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

test("preserves the Workspace tree viewport across polling snapshots", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("var treeScrollY = workspaceTreeList ? workspaceTreeList.contentY : 0")
  expect(panel.match(/restoreWorkspaceTreeScroll\(treeScrollY\)/g)).toHaveLength(2)
  expect(panel).toContain("var workspaceModelChanged = applyWorkspaceSnapshot(")
  expect(panel).toContain("WorkspaceModel.workspaceTreeModelSignature(nextWorkspaces)")
  expect(panel).toContain("if (signature === workspaceTreeSnapshotSignature) return false")
  expect(panel).toContain("model: root.workspaceTreeWorkspaces")
  expect(panel).toContain('if (root.pendingWorkspacePositionKey !== "") return')
  expect(panel).toContain("workspaceTreeList.contentY = Math.max(0,")
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
  test("preserves additive Node route, revision, and helper version fields", () => {
    const snapshot = model.normalizeNodeSnapshot({ nodes: [{
      node_id: "remote", alias: "build", local: false, route: "builder.example",
      registration_revision: 7, health: "authentication_required", current: false,
      stale: true, observed_at_ms: 100, observed_protocol_version: 41,
      observed_helper_version: "0.29.1",
      observed_capabilities: ["observed_node_helper_version", "node_upgrade_coordination"],
      workspace_owner_eligible: false,
      workspace_owner_unavailable_reason: "authentication required",
      remote_projection: null
    }] })
    expect(snapshot.nodes[0]).toMatchObject({
      route: "builder.example", registration_revision: 7,
      observed_helper_version: "0.29.1", observed_protocol_version: 41
    })
  })

  test("parses protocol 38 into one task-first multi-placement Workspace", () => {
    const snapshot = normalized()
    const release = snapshot.workspaces.find(workspace => workspace.id === "global-1")
    expect(model.snapshotSupportsGlobalWorkspaces(snapshot.nodes)).toBe(true)
    expect(release.key).toBe("global\u001fglobal-1")
    expect(release.placements).toHaveLength(3)
    expect(release.shells.map(shell => [shell.node_id, shell.id])).toEqual([
      ["node-a", "resource-shared"], ["node-b", "resource-shared"]
    ])
    expect(release.placements[1].default_cwd).toBe("/srv/release")
    expect(snapshot.nodes.map(node => [node.workspace_count, node.shell_count,
      node.agent_count, node.launcher_count])).toEqual([
      [1, 1, 1, 1],
      [1, 1, 1, 1],
      [0, 0, 0, 0]
    ])
    const external = snapshot.workspaces.filter(workspace => workspace.is_external)
    expect(external).toHaveLength(2)
    expect(new Set(external.map(workspace => workspace.key)).size).toBe(2)

    const localNode = snapshot.nodes.find(node => node.node_id === "node-a")
    const rawOwner = protocol38Envelope.data.nodes[0].local_snapshot.workspaces[0]
    const ownerDetail = model.normalizeWorkspaceDetail(rawOwner, {
      id: "owner-shared", key: "node-a\u001fowner-shared", placement_state: "active"
    }, localNode)
    expect(protocol38Envelope.data.nodes[0].scheduler.state).toBe("active")
    expect(protocol38Envelope.data.nodes[1].remote_projection.schedules).toHaveLength(1)
    expect(snapshot.nodes.some(node => "scheduler" in node)).toBe(false)
    expect(snapshot.workspaces.some(workspace => "schedules" in workspace)).toBe(false)
    expect("schedules" in ownerDetail).toBe(false)
    expect(release.shells.map(shell => shell.id)).not.toContain("private-shell")
    expect(release.agents.map(agent => agent.id)).not.toContain("private-agent")
    expect(snapshot.shells.map(shell => shell.id)).not.toContain("private-shell")
    expect(snapshot.agents.map(agent => agent.id)).not.toContain("private-agent")
    expect(ownerDetail.shell_count).toBe(1)
    expect(ownerDetail.agents.map(agent => agent.id)).toEqual(["agent-shared"])
  })

  test("preserves duplicate inner resource IDs as qualified identities", () => {
    const snapshot = normalized()
    expect(new Set(snapshot.shells.map(shell => shell.key)).size).toBe(2)
    expect(new Set(snapshot.agents.map(agent => agent.key)).size).toBe(2)
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

  test("excludes private runner Shells from legacy Workspace counts", () => {
    const shells = [
      { id: "user", node_id: "local-node", workspace_id: "legacy-workspace", owner: "user" },
      { id: "private", node_id: "local-node", workspace_id: "legacy-workspace",
        owner: { kind: "schedule", schedule_id: "legacy" } }
    ]
    expect(model.userShellCount(shells, "local-node", "legacy-workspace")).toBe(1)
    const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
    expect(panel).toContain("WorkspaceModel.userShellCount(root.shells")
    expect(panel).not.toContain("function workspaceItemCount(workspace)")
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
        observation: { revision: 1, state: "working", observed_at_ms: 1 } }]
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
    expect(model.workspaceOpenCommand(global, true)).toEqual([
      "boomux", "workspace", "open", "global-1", "--show"
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
