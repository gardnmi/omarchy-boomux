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
  const afterStatus = model.workspaceTreeModelSignature([workspace])
  workspace.placements = [{ node_id: "node", workspace_id: "owner", state: "active",
    default_cwd: "/new/default" }]
  expect(model.workspaceTreeModelSignature([workspace])).not.toBe(afterStatus)
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
  expect(panel).toContain("omarchy-launch-tui --app-id=TUI.float boomux config edit")
  expect(panel).toContain("Qt.callLater(function() { settingsBackButton.forceActiveFocus() })")
  expect(panel).toContain("KeyNavigation.tab: settingsLeftButton")
  expect(panel).not.toMatch(/palette/i)
  expect(panel).toContain("confirmationDialogKeyHandler.forceActiveFocus()")
  expect(panel).toContain("confirmationDialog.handleKey(event)")
  expect(panel).not.toContain('root.activeTab === "schedules"')
})

test("shows the installed Boomux CLI version in the pane header", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: boomuxHeaderTitle")
  expect(panel).toContain('(root.cliVersion !== "" ? "v" + root.cliVersion + " · " : "")')
})

test("separates persistent pane visibility from explicit keyboard mode", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const sidePane = fs.readFileSync(new URL("../SidePane.qml", import.meta.url), "utf8")
  const readme = fs.readFileSync(new URL("../README.md", import.meta.url), "utf8")
  expect(panel).toContain("function focusPane()")
  expect(panel).toContain("if (opened && panel.keyboardMode)")
  expect(panel).toContain("panel.exitKeyboardMode()")
  expect(panel).toContain("function focus(): void { root.focusPane() }")
  expect(panel).toContain("function releaseFocus(): void { panel.exitKeyboardMode() }")
  expect(panel).toContain("PanelKeyCatcher {")
  expect(panel).toContain('text: "BOOMUX"')
  expect(sidePane).toContain("property bool keyboardMode: false")
  expect(sidePane).toContain("function enterKeyboardMode()")
  expect(sidePane).toContain("function exitKeyboardMode()")
  expect(sidePane).toContain("WlrLayershell.keyboardFocus: keyboardMode")
  expect(sidePane).toContain("keyboardMode = false")
  expect(sidePane).toContain("id: keyboardDismissArea")
  expect(sidePane).toContain("root.keyboardMode ? keyboardDismissArea : card")
  expect(sidePane).toContain("onClicked: root.exitKeyboardMode()")
  expect(sidePane).toContain("id: focusEntryAnimation")
  expect(sidePane).toContain("property real focusEmphasis: 0")
  expect(sidePane).toContain("x: root.onRight ? 0 : parent.width - width")
  expect(sidePane).toContain("width: Math.max(7, Style.space(7))")
  expect(sidePane).toContain("width: Math.max(18, Style.space(18))")
  expect(panel).toContain("focusColor: root.urgent")
  expect(readme).not.toContain("release = true")
  expect(readme).toContain("releaseFocus")
  expect(readme).toContain("hl.dsp.focus({ direction = direction })")
})

test("shows one flat Agent list ordered by latest update", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("readonly property var paneAgents: visibleAgents")
  expect(panel).toContain("Math.min(contentHeight, Style.space(700))")
  expect(panel).not.toContain("panel.height - workspaceTreeColumn.implicitHeight")
  expect(panel).not.toContain('section.property: "workspace_name"')
  expect(panel).not.toContain("WorkspaceModel.agentsByWorkspace")
  expect(panel).toContain("readonly property bool keyboardSelected: selected && panel.keyboardMode")
  expect(panel).toContain("readonly property color keyboardCursorFill: Util.alpha(foreground, 0.065)")
  expect(panel).toContain("color: keyboardSelected ? root.keyboardCursorFill")
  expect(panel).toContain("(selected || agentMouse.containsMouse) ? root.keyboardCursorFill")
  expect(panel.match(/cursorSelected \? root\.keyboardCursorFill/g)).toHaveLength(2)
  expect(panel).not.toContain("border.color: keyboardSelected")
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
  expect(panel).toContain("Boomux update running in terminal...")
  expect(panel).toContain("Boomux update did not complete · run boomux update in a terminal to review the error")
  expect(panel).toContain("id: localUpdateVerificationTimer")
  expect(panel).toContain("!WorkspaceModel.versionIsNewer(localUpdateExpectedVersion, current)")
  expect(panel).toContain("Update with the AUR or package helper that installed Boomux.")
  expect(panel).not.toContain('root.actionMessage = "Boomux update finished"')
  expect(panel).not.toContain('localUpdateProcess.command = ["curl"')
  expect(model.guidedLocalUpdateCommand()).toEqual([
    "omarchy-launch-tui", "--app-id=TUI.float", "boomux", "update"
  ])
})

test("confirms plugin updates before invoking Omarchy once", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("function requestPluginUpdate()")
  expect(panel).toContain('confirmationTarget = { kind: "plugin-update" }')
  expect(panel).toContain('if (item.kind === "plugin-update") return "Update"')
  expect(panel).toContain("WorkspaceModel.guidedPluginUpdateCommand()")
  expect(panel).toContain("onClicked: root.requestPluginUpdate()")
  expect(panel).not.toContain("onClicked: Qt.openUrlExternally(root.pluginRepositoryUrl)")
  expect(model.guidedPluginUpdateCommand()).toEqual([
    "omarchy-launch-tui", "--app-id=TUI.float", "omarchy", "plugin", "update",
    "io.github.gardnmi.boomux", "--yes"
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
    "omarchy-launch-tui", "--app-id=TUI.float",
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
  const updateNode = panel.match(/function updateNode\(node\) \{[\s\S]*?\n  \}/)?.[0]
  expect(updateNode).toBeDefined()
  expect(updateNode).not.toContain("close()")
  expect(panel).toContain("Update Boomux on this control machine before managing the Node.")
  expect(panel).toContain("cached data retained · retrying automatically")
})

test("clearly separates guided Node uninstall from local registration forget", () => {
  const features = ["node_uninstall_coordination"]
  const remote = {
    node_id: "node;$(false)", local: false, current: true, stale: false,
    observed_capabilities: features
  }
  expect(model.nodeCanUninstall(remote, features, 48)).toBe(true)
  expect(model.nodeCanUninstall(Object.assign({}, remote, { current: false }), features, 48)).toBe(false)
  expect(model.nodeCanUninstall(Object.assign({}, remote, { stale: true }), features, 48)).toBe(false)
  expect(model.nodeCanUninstall(Object.assign({}, remote, { local: true }), features, 48)).toBe(false)
  expect(model.nodeCanUninstall(remote, [], 48)).toBe(false)
  expect(model.nodeCanUninstall(remote, features, 47)).toBe(false)
  expect(model.guidedNodeUninstallCommand(remote.node_id)).toEqual([
    "omarchy-launch-tui", "--app-id=TUI.float",
    "boomux", "node", "uninstall", "node;$(false)"
  ])

  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('text: "Uninstall Boomux"')
  expect(panel).toContain('return "Uninstall"')
  expect(panel).toContain('return "Just Forget"')
  expect(panel).toContain("preserves durable state and configuration")
  expect(panel).toContain("It does not contact the Node or stop its processes.")
  expect(panel).toContain("WorkspaceModel.guidedNodeUninstallCommand(item.node.node_id)")
  expect(panel).not.toContain('actionMessage = "Node uninstalled"')
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
    "omarchy-launch-tui", "--app-id=TUI.float",
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
  expect(panel).toContain("model: workspaceTreeDelegate.workspaceExpanded")
  expect(panel).toContain("? workspaceTreeDelegate.treeItems : []")
  expect(panel).not.toContain("else if (root.expandedWorkspaceKey !== \"\")")
  expect(panel).not.toContain("setWorkspaceTreeHeight(workspaceTreeHeight)")
  expect(panel).toContain("panel.height - Style.space(260)")
  expect(panel).not.toContain("workspaceTreeList.positionViewAtIndex(index, ListView.Contain)")
  expect(panel).toContain("root.activateWorkspaceRow(workspaceTreeDelegate.modelData)")
  expect(panel).toContain("if (panel.keyboardMode) return")
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
  expect(panel).toContain('var tabs = ["agents", "sessions", "nodes"]')
  expect(panel).toContain('else if (text === "2") root.selectTab("sessions")')
  expect(panel).toContain('else if (text === "3") root.selectTab("nodes")')
  expect(panel).not.toContain('root.selectTab("schedules")')
  expect(panel).toContain('width: (parent.width - parent.spacing * 2) / 3')
  expect(panel).not.toContain("Enter opens · D dismisses · Tab switches · R refreshes")
  expect(panel).not.toContain("Up/Down selects · A creates a Node · Tab switches · R refreshes")
  expect(panel).not.toContain("id: actionStatusText")
  expect(panel).not.toContain('tooltipText: "Dismiss status"')
  expect(panel).toContain("onActionMessageChanged:")
  expect(panel).toContain('showNotice("Boomux", actionMessage, currentNoticeScreen(), true)')
  expect(panel).not.toContain('root.actionMessage = "Workspace shown"')
  expect(sidePane).toContain('WlrLayershell.namespace: "omarchy-boomux-side-pane"')
  expect(sidePane).toContain('WlrLayershell.namespace: "omarchy-boomux-side-pane-reservation"')
  expect(sidePane).toContain("exclusiveZone: implicitWidth")
  expect(sidePane).toContain("left: !root.onRight")
  expect(sidePane).toContain("right: root.onRight")
  expect(sidePane).toContain("mask: Region { item: root.keyboardMode ? keyboardDismissArea : card }")
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
  expect(panel).toContain('if (focusSection === "workspaces" || focusSection === "workspace-items")')
  expect(panel).toContain('pendingWorkspacePositionKey = ""')
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
  expect(manifest.version).toBe("2.5.0")
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
  expect(panel).toContain('x: root.paneSide === "left"')
  expect(panel).toContain("panel.sideInset + Style.space(18)")
  expect(panel).toContain("parent.width - width - panel.sideInset - Style.space(18)")
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
  expect(readme).toContain("Switch Agents, Sessions, and Nodes")
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
  expect(panel).toContain("WorkspaceModel.resolveAtomicWorkspaceCreation(")
})

test("uses atomic Workspace creation from plus, N, and configured projects", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('iconText: ""')
  expect(panel).not.toContain('text: "From Projects"')
  expect(panel).toContain("visible: root.online && root.projectListSupported")
  expect(panel).toContain("&& root.projectRootsConfigured")
  expect(panel).toContain("onClicked: root.requestGeneratedWorkspace(root.home)")
  expect(panel).toContain('else if (text === "n" || text === "N") root.requestGeneratedWorkspace(root.home)')
  expect(panel).toContain("requestGeneratedWorkspace(projectPath, projectName)")
  expect(panel).toContain("var projectName = String(selectedProject.name)")
  expect(panel).toContain("WorkspaceModel.atomicWorkspaceCreateCommand(")
  expect(panel.match(/WorkspaceModel\.atomicWorkspaceCreateCommand\(/g)).toHaveLength(1)
  expect(panel).toContain("command: WorkspaceModel.workspaceDaemonStartCommand()")
  expect(panel).toContain('workspaceCreateRequested = { cwd: path, name: String(name || "") }')
  expect(panel).toContain("daemonStatusProcess.running = true")
  expect(panel).toContain("requestFreshWorkspaceCreateStatus()")
  expect(panel).toContain("requestFreshWorkspaceCreateSnapshot()")
  expect(panel).toContain("if (explicitCreationSnapshot) maybeStartWorkspaceCreation()")
  expect(panel).not.toContain("if (online) maybeStartWorkspaceCreation()")
  expect(panel).toContain("maybeStartWorkspaceCreation()")
  expect(panel).toContain('root.parseEnvelope(workspaceCreateStdout.text, "workspace.create")')
  expect(panel).not.toContain('showForm("workspace")')
  expect(panel).not.toContain('placeholderText: "Workspace name"')
  expect(panel).not.toContain('kind: "create-workspace-shell"')
  expect(panel).not.toContain("workspaces[p].name ===")
})

test("requires an explicit project selection and marks only clicked rows", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("property int selectedProjectIndex: -1")
  expect(panel).toContain("onClicked: root.selectedProjectIndex = index")
  expect(panel).not.toContain("onEntered: root.selectedProjectIndex = index")
  expect(panel).toContain("border.width: index === root.selectedProjectIndex ? 1 : 0")
  expect(panel).toContain("if (selectedProjectIndex < 0)")
})

test("makes directory selection path-aware and action-oriented", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('? "SHELL START FOLDER" : "CHOOSE DIRECTORY"')
  expect(panel).toContain("Choose where new Shells in this Workspace should start.")
  expect(panel).toContain("root.directoryDisplayName(root.directoryPickerPath)")
  expect(panel).toContain("text: root.directoryPickerPath")
  expect(panel).toContain('onClicked: root.enterDirectory(filePath)')
  expect(panel).not.toContain("onDoubleClicked: root.enterDirectory(filePath)")
  expect(panel).toContain('? "Start New Shells Here" : "Use This Folder"')
  expect(panel).toContain('text: "Go Up"')
  expect(panel).not.toContain('iconText: "←"')
  expect(panel).toContain("enabled: root.directoryPickerCanGoUp")
  expect(panel).not.toContain('text: "Choose Here"')
  expect(panel).not.toContain('text: "Change Default Path"')
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
    "omarchy-launch-tui --app-id=TUI.float boomux __guided-node-add"
  )
  const createNode = panel.match(/function createNode\(\) \{[\s\S]*?\n  \}/)?.[0]
  expect(createNode).toBeDefined()
  expect(createNode).not.toContain("close()")
})

test("does not show the Boomux TUI header action", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).not.toContain('tooltipText: "Open Boomux TUI"')
  expect(panel).not.toContain("function openDashboard()")
})

test("refreshes the installed CLI version after an upgrade", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("onOpenedChanged: if (opened) {\n    openRefreshTimer.restart()")
  expect(panel).toContain("id: openRefreshTimer")
  expect(panel).toContain("interval: 200")
  expect(panel).toContain("onTriggered: if (root.opened) root.refreshInstalledState()")
  expect(panel).toContain('if (text === "r" || text === "R") root.requestExplicitRefresh()')
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

describe("Agent Sessions", () => {
  const local = { node_id: "local-node", alias: "local", local: true,
    current: true, stale: false, health: "online", observed_capabilities: [] }
  const remoteFeatures = ["typed_node_host_services", "remote_agent_session_catalog"]
  const remote = { node_id: "node;$(false)", alias: "build", local: false,
    current: true, stale: false, health: "online", observed_protocol_version: 49,
    observed_capabilities: remoteFeatures }
  const summary = (overrides = {}) => Object.assign({
    id: "session;$(false)", workspace_id: "workspace", workspace_name: "Project",
    description: "Fix tests", integration: "opencode", external_session_id: "external",
    state: "idle", state_is_current: false, started_at_ms: 100, last_at_ms: 200,
    occurrence_count: 1
  }, overrides)
  const observation = { revision: 4, state: "idle", authority: "lifecycle_integration",
    evidence: "turn complete", confidence: 100, observed_at_ms: 200 }
  const envelope = (command, data) => ({ schema: "boomux.cli/v1", command, data })

  test("strictly normalizes local and remote list envelopes", () => {
    const localSessions = model.normalizeSessionList(envelope("session.list", {
      sessions: [summary()]
    }), local)
    expect(localSessions[0]).toMatchObject({ node_id: "local-node", node_local: true,
      key: "local-node\u001fsession;$(false)" })
    const remoteSessions = model.normalizeSessionList(envelope("session.list", {
      node_id: remote.node_id, sessions: [summary()]
    }), remote)
    expect(remoteSessions[0]).toMatchObject({ node_id: remote.node_id, node_alias: "build",
      node_local: false })
    expect(() => model.normalizeSessionList(envelope("session.inspect", {
      sessions: []
    }), local)).toThrow()
    expect(() => model.normalizeSessionList(envelope("session.list", {
      node_id: "unexpected", sessions: []
    }), remote)).toThrow()
    expect(() => model.normalizeSessionList(envelope("session.list", {
      node_id: local.node_id, sessions: []
    }), local)).toThrow()
    expect(() => model.normalizeSessionList(envelope("session.list", {
      sessions: [summary({ state_is_current: "false" })]
    }), local)).toThrow()
    for (const invalid of [
      summary({ state: "surprising" }),
      summary({ last_at_ms: 1.5 }),
      summary({ last_at_ms: 1e100 }),
      summary({ occurrence_count: 1.5 })
    ]) expect(() => model.normalizeSessionList(envelope("session.list", {
      sessions: [invalid]
    }), local)).toThrow()
  })

  test("keeps qualified collisions distinct and sorts deterministic newest-first ties", () => {
    const values = [
      { node_id: "node-b", workspace_id: "workspace-a", id: "same", last_at_ms: 300 },
      { node_id: "node-a", workspace_id: "workspace-b", id: "same", last_at_ms: 300 },
      { node_id: "node-a", workspace_id: "workspace-a", id: "z", last_at_ms: 300 },
      { node_id: "node-a", workspace_id: "workspace-a", id: "a", last_at_ms: 300 },
      { node_id: "node-a", workspace_id: "workspace-a", id: "old", last_at_ms: 200 }
    ]
    expect(model.sessionsNewestFirst(values).map(value =>
      [value.node_id, value.workspace_id, value.id])).toEqual([
      ["node-a", "workspace-a", "a"], ["node-a", "workspace-a", "z"],
      ["node-a", "workspace-b", "same"], ["node-b", "workspace-a", "same"],
      ["node-a", "workspace-a", "old"]
    ])
    expect(model.sessionIdentityMatches({ node_id: "node-a", id: "same" },
      "node-a", "same")).toBe(true)
    expect(model.sessionIdentityMatches({ node_id: "node-b", id: "same" },
      "node-a", "same")).toBe(false)
  })

  test("builds exact local and remote argv without shell interpolation", () => {
    const session = { id: "session;$(touch /tmp/no)", node_id: remote.node_id,
      node_local: false }
    expect(model.sessionListCommand(local)).toEqual([
      "boomux", "session", "list", "--json"
    ])
    expect(model.sessionListCommand(remote)).toEqual([
      "boomux", "session", "list", "--json", "--node", "node;$(false)"
    ])
    expect(model.sessionInspectCommand(session)).toEqual([
      "boomux", "session", "inspect", "session;$(touch /tmp/no)", "--json",
      "--node", "node;$(false)"
    ])
    expect(model.sessionOpenCommand(session)).toEqual([
      "boomux", "session", "open", "session;$(touch /tmp/no)",
      "--node", "node;$(false)"
    ])
    const localSession = Object.assign({}, session, { node_id: local.node_id, node_local: true })
    expect(model.sessionInspectCommand(localSession)).toEqual([
      "boomux", "session", "inspect", "session;$(touch /tmp/no)", "--json"
    ])
    expect(model.sessionOpenCommand(localSession)).toEqual([
      "boomux", "session", "open", "session;$(touch /tmp/no)"
    ])
  })

  test("normalizes documented local occurrence fields", () => {
    const occurrence = { agent_id: "agent", shell_id: "shell", retained_shell_name: "main",
      retained_shell_cwd: "/home/user/project", source_cwd: "/home/user/project",
      run_id: "run", started_at_ms: 100, ended_at_ms: null, is_current: true,
      observation }
    const detail = model.normalizeSessionInspect(envelope("session.inspect", {
      session: Object.assign(summary(), { source_cwd: "/home/user/project",
        occurrences: [occurrence] })
    }), local, "session;$(false)")
    expect(detail.occurrences[0]).toMatchObject({ agent_id: "agent", is_current: true,
      remote_raw: false, retained_shell_name: "main" })
  })

  test("normalizes current remote raw Agent-instance occurrences for display only", () => {
    const occurrence = { id: "agent", workspace_id: "workspace", shell_id: "shell",
      run_id: "run", name: "Agent", integration: "opencode",
      external_session_id: "external", cwd: "/srv/project", started_at_ms: 100,
      ended_at_ms: null, observation }
    const detail = model.normalizeSessionInspect(envelope("session.inspect", {
      node_id: remote.node_id, session: Object.assign(summary(), {
        source_cwd: "/srv/project", occurrences: [occurrence] })
    }), remote, "session;$(false)")
    expect(detail.occurrences[0]).toMatchObject({ agent_id: "agent", source_cwd: "/srv/project",
      is_current: true, remote_raw: true, retained_shell_name: null })
    expect(() => model.normalizeSessionInspect(envelope("session.inspect", {
      node_id: "other", session: Object.assign(summary(), {
        source_cwd: null, occurrences: [occurrence] })
    }), remote, "session;$(false)")).toThrow()
    expect(() => model.normalizeSessionInspect(envelope("session.inspect", {
      node_id: remote.node_id, session: Object.assign(summary({ id: "other" }), {
        source_cwd: null, occurrences: [occurrence] })
    }), remote, "session;$(false)")).toThrow()
    for (const invalidObservation of [
      Object.assign({}, observation, { revision: 1.5 }),
      Object.assign({}, observation, { state: "surprising" }),
      Object.assign({}, observation, { authority: "untrusted" }),
      Object.assign({}, observation, { confidence: 101 })
    ]) expect(() => model.normalizeSessionInspect(envelope("session.inspect", {
      node_id: remote.node_id, session: Object.assign(summary(), {
        source_cwd: "/srv/project", occurrences: [Object.assign({}, occurrence,
          { observation: invalidObservation })] })
    }), remote, "session;$(false)")).toThrow()
    expect(() => model.normalizeSessionInspect(envelope("session.inspect", {
      node_id: remote.node_id, session: Object.assign(summary(), {
        source_cwd: "relative/project", occurrences: [occurrence] })
    }), remote, "session;$(false)")).toThrow()
  })

  test("gates Nodes, activation, and stale generations exactly", () => {
    expect(model.sessionNodeEligible(local, [])).toBe(true)
    expect(model.sessionNodeEligible(remote, remoteFeatures)).toBe(true)
    expect(model.sessionNodeEligible(Object.assign({}, remote, { stale: true }),
      remoteFeatures)).toBe(false)
    expect(model.sessionNodeEligible(Object.assign({}, remote,
      { observed_capabilities: ["typed_node_host_services"] }), remoteFeatures)).toBe(false)
    expect(model.sessionNodeEligible(Object.assign({}, remote,
      { observed_protocol_version: 35 }), remoteFeatures)).toBe(false)
    expect(model.sessionNodeEligible(remote, ["typed_node_host_services"])).toBe(false)
    expect(model.sessionActionable({ state: "idle" }, true, true)).toBe(true)
    expect(model.sessionActionable({ state: "done" }, true, true)).toBe(false)
    const request = { generation: 7, nodeId: remote.node_id, cliFeatures: remoteFeatures }
    expect(model.sessionRequestCurrent(request, 7, true, "sessions", true, remote)).toBe(true)
    expect(model.sessionRequestCurrent(request, 8, true, "sessions", true, remote)).toBe(false)
    expect(model.sessionRequestCurrent(request, 7, false, "sessions", true, remote)).toBe(false)
    expect(model.sessionRequestCurrent(request, 7, true, "agents", true, remote)).toBe(false)
    expect(model.boundedSessionWarnings(["a", "b", "c", "d"], 2)).toBe("a · b · +2 more")
    expect(["opencode", "pi", "claude", "codex", "kiro"].map(model.sessionHarnessLabel))
      .toEqual(["OpenCode", "Pi", "Claude Code", "Codex", "Kiro CLI"])
  })

  test("integrates three tabs, lazy fan-out, privacy clearing, details, and two-click open", () => {
    const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
    expect(panel).toContain('var tabs = ["agents", "sessions", "nodes"]')
    expect(panel).toContain('text: "Sessions"')
    expect(panel).toContain('data.json_commands.indexOf("session.list") >= 0')
    expect(panel).toContain('data.json_commands.indexOf("session.inspect") >= 0')
    expect(panel).toContain('cliFeatures.indexOf("projected_agent_sessions") >= 0')
    expect(panel).toContain('cliFeatures.indexOf("exact_session_open") >= 0')
    expect(panel).toContain('running: root.opened && root.activeTab === "sessions"')
    expect(panel).toContain('sessionExpiresAt = Date.now() + 10000')
    expect(panel).toContain('if (sessionExpiresAt === 0 || Date.now() >= sessionExpiresAt)')
    expect(panel).toContain('sessionResults = ({})')
    expect(panel).toContain('sessionRefreshAfterSnapshot = refreshSessions && !nodeSnapshotProcess.running')
    expect(panel).toContain('sessionSnapshotRefreshQueued = refreshSessions && nodeSnapshotProcess.running')
    expect(panel).toContain('if (sessionRefreshAfterSnapshot) {')
    expect(panel).toContain('id: sessionListProcess')
    expect(panel).toContain('if (sessionListProcess.running)')
    expect(panel).toContain('WorkspaceModel.sessionRequestCurrent(request, root.sessionGeneration')
    expect(panel).toContain('var nextResults = Object.assign({}, root.sessionResults)')
    expect(panel).toContain('nextResults[request.nodeId] = WorkspaceModel.normalizeSessionList(')
    expect(panel).toContain('clearSessionPrivacy()')
    expect(panel).toContain('stopAndClearSessionProcess(sessionOpenProcess)')
    expect(panel).toContain('id: sessionCollectorFactory')
    expect(panel).toContain('root.clearSessionProcessOutput(sessionInspectProcess)')
    expect(panel).toContain('Qt.callLater(root.recoverStoppedSessionList)')
    expect(panel).toContain('Qt.callLater(root.recoverStoppedSessionInspect)')
    expect(panel).toContain('Qt.callLater(root.recoverStoppedSessionOpen)')
    expect(panel).toContain('onFocusSectionChanged: if (focusSection !== "lower")')
    expect(panel).toContain('sessionDetail = null')
    expect(panel).toContain('var alreadySelected = root.sessionPointerSelectedKey === modelData.key')
    expect(panel).toContain('if (alreadySelected && sessionRow.actionable) root.openSession(modelData)')
    expect(panel).toContain('else if (activeTab === "sessions") openSession(selectedItem)')
    expect(panel).toContain('root.inspectSession(root.selectedItem)')
    expect(panel).toContain('root.compactPath(root.sessionDetail.source_cwd)')
    expect(panel).toContain('if (root.sessionDetail) return')
    expect(panel).toContain('function sessionStatusLabel(session)')
    expect(panel).toContain('function sessionActionLabel(session)')
    expect(panel).toContain('WorkspaceModel.sessionOpenCommand(session)')
    expect(panel).not.toContain('session", "resume"')
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

  test("atomically creates one generated Workspace and Shell on the exact local Node", () => {
    expect(model.workspaceDaemonStartCommand()).toEqual([
      "boomux", "workspace", "list", "--json"
    ])
    expect(model.atomicWorkspaceCreateCommand(
      "node;$(false)", "/tmp/project with spaces/;rm -rf --no")).toEqual([
      "boomux", "workspace", "create", "--node", "node;$(false)",
      "--cwd", "/tmp/project with spaces/;rm -rf --no", "--json"
    ])
    const local = model.localWorkspaceCreationNode(protocol38Envelope.data.nodes)
    expect(local.node_id).toBe("node-a")
    expect(model.localWorkspaceCreationNode([protocol38Envelope.data.nodes[1]])).toBeNull()
    expect(model.localWorkspaceCreationNode(protocol38Envelope.data.nodes.map(node =>
      Object.assign({}, node, { local: false })))).toBeNull()
    expect(model.localWorkspaceCreationNode([Object.assign({}, local, { stale: true })])).toBeNull()
    expect(model.localWorkspaceCreationNode([Object.assign({}, local,
      { health: "reconnecting" })])).toBeNull()
    expect(model.localWorkspaceCreationNode([local, Object.assign({}, local,
      { node_id: "duplicate-local" })])).toBeNull()
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

  test("validates atomic response identities and resolves only exact snapshot IDs", () => {
    const response = {
      workspace: { id: "global-new", name: "generated-name", revision: 3 },
      placement: { node_id: "node-a", owner_workspace_id: "owner-new",
        default_cwd: "/home/a/project $(safe)" },
      shell: { id: "shell-new", name: "generated-shell", node_id: "node-a",
        cwd: "/home/a/project $(safe)" }
    }
    const identity = model.atomicWorkspaceCreateIdentity(response, "node-a")
    expect(identity).toEqual({
      workspaceId: "global-new", workspaceName: "generated-name", workspaceRevision: 3,
      nodeId: "node-a", ownerWorkspaceId: "owner-new",
      defaultCwd: "/home/a/project $(safe)", shellId: "shell-new",
      shellName: "generated-shell"
    })
    const snapshot = [{
      id: "global-new", name: "generated-name", is_global: true, revision: 3,
      placements: [{ node_id: "node-a", workspace_id: "owner-new",
        default_cwd: "/home/a/project $(safe)", state: "active" }],
      shells: [{ id: "shell-new", name: "generated-shell", node_id: "node-a",
        cwd: "/home/a/project $(safe)" }]
    }]
    expect(model.resolveAtomicWorkspaceCreation(identity, snapshot)).toMatchObject({
      workspace: { id: "global-new" }, shell: { id: "shell-new" }
    })
    expect(model.resolveAtomicWorkspaceCreation(Object.assign({}, identity,
      { shellId: "same-name-wrong-id" }), snapshot)).toBeNull()
    expect(model.atomicWorkspaceCreationConflicts(Object.assign({}, identity,
      { shellId: "same-name-wrong-id" }), snapshot)).toBe(true)
    expect(model.resolveAtomicWorkspaceCreation(identity, [Object.assign({}, snapshot[0],
      { name: "wrong-workspace-name" })])).toBeNull()
    expect(model.resolveAtomicWorkspaceCreation(identity, [Object.assign({}, snapshot[0], {
      shells: [Object.assign({}, snapshot[0].shells[0], { name: "wrong-shell-name" })]
    })])).toBeNull()
    expect(() => model.atomicWorkspaceCreateIdentity(Object.assign({}, response, {
      placement: Object.assign({}, response.placement, { node_id: "node-b" })
    }), "node-a")).toThrow()
    expect(() => model.atomicWorkspaceCreateIdentity(Object.assign({}, response, {
      workspace: Object.assign({}, response.workspace, { revision: 0 })
    }), "node-a")).toThrow()
    expect(() => model.atomicWorkspaceCreateIdentity(Object.assign({}, response, {
      placement: Object.assign({}, response.placement, { default_cwd: "relative" })
    }), "node-a")).toThrow()
    expect(() => model.atomicWorkspaceCreateIdentity(Object.assign({}, response, {
      shell: Object.assign({}, response.shell, { cwd: "/different/canonical" })
    }), "node-a")).toThrow()
  })

  test("uses the returned canonical creation path instead of requested path spelling", () => {
    const response = {
      workspace: { id: "global-new", name: "generated-name", revision: 3 },
      placement: { node_id: "node-a", owner_workspace_id: "owner-new",
        default_cwd: "/canonical/project" },
      shell: { id: "shell-new", name: "generated-shell", node_id: "node-a",
        cwd: "/canonical/project" }
    }
    expect(model.atomicWorkspaceCreateIdentity(response, "node-a").defaultCwd)
      .toBe("/canonical/project")
  })

  test("uses the discovered project name and path unchanged in one atomic creation command", () => {
    const project = { name: "project; $(not-a-shell)", path: "/work/space; $(not-a-shell)" }
    expect(model.atomicWorkspaceCreateCommand("node-a", project.path, project.name)).toEqual([
      "boomux", "workspace", "create", "project; $(not-a-shell)", "--node", "node-a", "--cwd",
      "/work/space; $(not-a-shell)", "--json"
    ])
  })

  test("gates and validates local coordinated Workspace default path changes", () => {
    const snapshot = normalized()
    const workspace = snapshot.workspaces.find(item => item.id === "global-1")
    const placement = model.localActiveWorkspacePlacement(workspace, snapshot.nodes)
    expect(placement).toMatchObject({ node_id: "node-a", workspace_id: "owner-shared" })
    expect(model.localActiveWorkspacePlacement(Object.assign({}, workspace,
      { closing: true }), snapshot.nodes)).toBeNull()
    expect(model.localActiveWorkspacePlacement(workspace, snapshot.nodes.map(node =>
      node.node_id === "node-a" ? Object.assign({}, node, { stale: true }) : node))).toBeNull()
    expect(model.workspaceDefaultCwdCommand(
      "global;$(false)", "node-a", "/path with spaces/;literal")).toEqual([
      "boomux", "workspace", "set-default-cwd", "global;$(false)",
      "--node", "node-a", "--cwd", "/path with spaces/;literal", "--json"
    ])

    const expected = { workspaceId: "global-1", nodeId: "node-a",
      ownerWorkspaceId: "owner-shared", defaultCwd: "/requested/symlink" }
    const identity = model.workspaceDefaultCwdIdentity({
      workspace_id: "global-1", node_id: "node-a", owner_workspace_id: "owner-shared",
      default_cwd: "/new/default path", global_revision: 9, owner_revision: 10,
      result: "updated"
    }, expected)
    const updated = [{ id: "global-1", is_global: true, revision: 9, placements: [{
      node_id: "node-a", workspace_id: "owner-shared", default_cwd: "/new/default path",
      owner_revision: 10, state: "active"
    }] }]
    expect(model.resolveWorkspaceDefaultCwd(identity, updated)).toMatchObject({
      workspace: { id: "global-1" }, placement: { owner_revision: 10 }
    })
    const newer = structuredClone(updated)
    newer[0].revision = 11
    newer[0].placements[0].owner_revision = 12
    expect(model.resolveWorkspaceDefaultCwd(identity, newer)).not.toBeNull()
    expect(model.resolveWorkspaceDefaultCwd(identity, [{ id: "global-1", is_global: true,
      revision: 8, placements: updated[0].placements }])).toBeNull()
    const conflicting = structuredClone(updated)
    conflicting[0].placements[0].default_cwd = "/changed-again"
    expect(model.workspaceDefaultCwdConflicts(identity, conflicting)).toBe(true)
    expect(() => model.workspaceDefaultCwdIdentity(Object.assign({}, {
      workspace_id: "global-1", node_id: "node-b", owner_workspace_id: "owner-shared",
      default_cwd: "/new/default path", global_revision: 9, owner_revision: 10,
      result: "updated"
    }), expected)).toThrow()
    expect(() => model.workspaceDefaultCwdIdentity({
      workspace_id: "global-1", node_id: "node-a", owner_workspace_id: "owner-shared",
      default_cwd: "relative", global_revision: 9, owner_revision: 10,
      result: "updated"
    }, expected)).toThrow()
    expect(() => model.workspaceDefaultCwdIdentity({
      workspace_id: "global-1", node_id: "node-a", owner_workspace_id: "owner-shared",
      default_cwd: "/new/default path", global_revision: 9, owner_revision: 10,
      result: "created"
    }, expected)).toThrow()
    expect(model.workspaceDefaultCwdIdentity({
      workspace_id: "global-1", node_id: "node-a", owner_workspace_id: "owner-shared",
      default_cwd: "/canonical/default", global_revision: 9, owner_revision: 10,
      result: "unchanged"
    }, expected).defaultCwd).toBe("/canonical/default")
  })
})

test("wires the protocol-49 default path action without optimistic updates", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain('data.json_commands.indexOf("workspace.set-default-cwd") >= 0')
  expect(panel).toContain('cliFeatures.indexOf("workspace_placement_default_cwd") >= 0')
  expect(panel).toContain("daemonProtocolVersion >= 49")
  expect(panel).toContain('text: "Shell Start Folder"')
  expect(panel).toContain('root.runActionMenuAction("default-path")')
  expect(panel).toContain("WorkspaceModel.workspaceDefaultCwdCommand(")
  expect(panel).toContain('root.parseEnvelope(defaultCwdStdout.text, "workspace.set-default-cwd")')
  expect(panel).toContain("WorkspaceModel.resolveWorkspaceDefaultCwd(pendingDefaultCwd, workspaces)")
  expect(panel).not.toContain("placement.default_cwd =")
})

test("requires a fresh status and authoritative Node snapshot for every creation intent", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  const request = panel.slice(panel.indexOf("function requestGeneratedWorkspace"),
    panel.indexOf("function resolvePendingWorkspaceCreation"))
  expect(request).toContain("requestFreshWorkspaceCreateStatus()")
  expect(request).toContain("workspaceCreateStatusActive = true")
  expect(request).toContain("workspaceCreateSnapshotActive = true")
  expect(request.indexOf("requestFreshWorkspaceCreateStatus()"))
    .toBeLessThan(request.indexOf("atomicWorkspaceCreateCommand("))
  expect(panel).toContain("if (explicitCreationCheck) requestFreshWorkspaceCreateSnapshot()")
  expect(panel).toContain("if (explicitCreationSnapshot) maybeStartWorkspaceCreation()")
  expect(panel).toContain("The refreshed Boomux daemon does not support coordinated Node snapshots")
  expect(panel).toContain("Could not obtain a fresh Boomux Node snapshot")
  expect(panel).toContain("workspaceCreateSnapshotQueued")
  expect(panel).toContain("workspaceCreateStatusQueued")
  expect(panel).toContain("if (workspaceCreateRequested && !daemonStartProcess.running)")
  const failure = panel.match(/function failWorkspaceCreation\(message\) \{[\s\S]*?\n  \}/)?.[0]
  expect(failure).toContain("workspaceCreateRequested = null")
  const status = panel.slice(panel.indexOf("function parseDaemonStatus"),
    panel.indexOf("function parseEnvelope"))
  expect(status.indexOf("daemonStartProcess.running = true"))
    .toBeLessThan(status.indexOf('setOffline("Boomux daemon is stopped")'))
})

test("bounds post-success snapshot confirmation without replaying mutations", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("id: mutationConfirmationTimer")
  expect(panel).toContain("Date.now() + 10000")
  expect(panel).toContain("function continueMutationConfirmation()")
  expect(panel).toContain("Workspace creation completed but could not be confirmed; refresh to verify it")
  expect(panel).toContain("Shell start folder changed but could not be confirmed; refresh to verify it")
  const confirmation = panel.slice(panel.indexOf("function continueMutationConfirmation"),
    panel.indexOf("function selectTab"))
  expect(confirmation).not.toContain("workspaceCreateProcess.running = true")
  expect(confirmation).not.toContain("defaultCwdProcess.running = true")
})

test("keeps project discovery online, fresh, retryable, and local", () => {
  const panel = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
  expect(panel).toContain("function invalidateProjectDiscovery()")
  expect(panel).toContain("projectDiscoveryExpiresAt = Date.now() + 30000")
  expect(panel).toContain("projectRefreshQueued = true")
  expect(panel).toContain("projectLoadedNodeId === node.node_id")
  expect(panel).toContain("if (!online || !projectDiscoveryLoaded || !selectedProject)")
  expect(panel).toContain("if (!online)")
  expect(panel).toContain("projectChooserRequested = true")
  expect(panel).toContain("openFreshProjectChooser()")
  expect(panel).toContain("visible: root.online && root.projectListSupported")
  expect(panel).toContain("invalidateProjectDiscovery()\n    if (!capabilityProcess.running)")
})

test("documents that generated Workspace creation does not open a terminal", () => {
  const readme = fs.readFileSync(new URL("../README.md", import.meta.url), "utf8")
  expect(readme).toContain("without opening a terminal")
  expect(readme).not.toContain("Shell, and opens it")
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
