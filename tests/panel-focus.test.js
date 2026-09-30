const { describe, expect, test } = require("bun:test")
const fs = require("node:fs")
const vm = require("node:vm")
const model = require("../WorkspaceModel.js")

const panelSource = fs.readFileSync(new URL("../Panel.qml", import.meta.url), "utf8")
const sideSource = fs.readFileSync(new URL("../SidePane.qml", import.meta.url), "utf8")

// Execute the actual QML JavaScript with inert controls, Processes and an explicit
// event-loop queue. These regressions do not emulate Qt key propagation or prove
// compositor focus. Live smoke: interrupt each editor with outside click, IPC
// focus and releaseFocus; resume, type, Tab and Escape. Launch each guided terminal
// from pointer/keyboard mode and verify it receives typing while the pane stays up.
function extractBlock(source, marker) {
  const start = source.indexOf(marker)
  if (start < 0) throw new Error("Missing source: " + marker)
  const open = source.indexOf("{", start)
  let depth = 1, quote = "", escaped = false, lineComment = false, blockComment = false
  for (let i = open + 1; i < source.length; i++) {
    const ch = source[i], next = source[i + 1]
    if (lineComment) { if (ch === "\n") lineComment = false; continue }
    if (blockComment) { if (ch === "*" && next === "/") { blockComment = false; i++ }; continue }
    if (quote) {
      if (escaped) escaped = false
      else if (ch === "\\") escaped = true
      else if (ch === quote) quote = ""
    } else if (ch === "/" && next === "/") { lineComment = true; i++ }
    else if (ch === "/" && next === "*") { blockComment = true; i++ }
    else if (ch === '"' || ch === "'" || ch === "`") quote = ch
    else if (ch === "{") depth++
    else if (ch === "}" && --depth === 0) return source.slice(start, i + 1)
  }
  throw new Error("Unterminated source: " + marker)
}

function installFunctions(context, source, names) {
  vm.runInContext(names.map(name => extractBlock(source, "function " + name + "("))
    .join("\n"), context)
}

function createHarness() {
  const queue = [], launches = [], focusHistory = []
  let activeFocus = "application"
  const Qt = { callLater(fn) { queue.push(fn) } }
  for (const key of ["Escape", "Down", "Up", "J", "K", "Return", "Enter", "Right",
    "Left", "Backspace", "Space", "Tab", "Backtab"]) Qt["Key_" + key] = key
  const state = vm.createContext({ Qt, WorkspaceModel: model, opened: true,
    terminalLaunchPending: false, formMode: "", directoryPickerOpen: false,
    directoryPickerPurpose: "resource", directoryPickerPath: "/tmp", directoryPickerIndex: 0,
    renameReturnToSessionRail: false, renameError: "", settingsOpen: false,
    actionMessage: "", sessionRailOpen: false, home: "/home/test", cwdIsExact: true,
    boomuxUpdateAvailable: false, pluginUpdateAvailable: true, cliAvailable: true,
    federationAvailable: true, activeBoomuxWorkspaceId: "workspace-1",
    guidedLocalUpdateSupported: true, boomuxUpdateAction: "run_update",
    online: true, projectChooserRequested: true, projectRootsConfigured: true,
    globalWorkspacesAvailable: false, eligibleCreationNodes: [],
    workspaceDetail: { node_id: "local", node_local: true, name: "Workspace" },
    confirmationDialog: { selectedIndex: 0 },
    nodeCanUninstall: () => true, nodeCanUpgrade: () => true,
    nodeCanReauthenticate: () => true, nodeIsActionable: () => true,
    nodeFor: () => ({ local: true }), workspaceCanRename: () => true,
    itemCanRename: () => true, applyCreationNodeDefaults() {}, requestShellNameSuggestion() {},
    open() { state.opened = true }, close() { state.opened = false },
    showActionFailure() {}, showNotice() {}, currentNoticeScreen: () => null
  })
  state.root = state
  for (const name of ["keyCatcher", "renameField", "settingsBackButton", "nameField",
    "projectSearchField", "directoryPickerKeyHandler", "confirmationDialogKeyHandler",
    "cwdField", "browseButton", "projectCancelButton", "directoryChooseButton",
    "directoryCancelButton"]) {
    state[name] = { visible: true, enabled: true, text: "draft", selectAll() {},
      forceActiveFocus() { activeFocus = name; focusHistory.push(name) } }
  }
  const pane = vm.createContext({ Qt, keyboardMode: false })
  pane.root = pane
  Object.defineProperties(pane, {
    open: { get: () => state.opened },
    keyboardModeBlocked: { get: () => state.terminalLaunchPending },
    focusTarget: { get: () => state.mainPaneFocusTarget() }
  })
  installFunctions(pane, sideSource, ["restoreKeyboardFocus", "enterKeyboardMode", "exitKeyboardMode"])
  state.panel = pane
  state.sessionRail = { keyboardMode: false,
    exitKeyboardMode() { this.keyboardMode = false } }
  function capture(command) {
    launches.push({ command, keyboardMode: pane.keyboardMode,
      railKeyboardMode: state.sessionRail.keyboardMode, opened: state.opened })
  }
  state.bar = { run: capture }
  for (const name of ["action", "nodeShell", "nodeUpgrade", "nodeUninstall",
    "nodeReauthenticate", "pluginUpdateLaunch", "localUpdate"]) {
    let running = false
    state[name + "Process"] = { command: [], get running() { return running },
      set running(value) { running = value; if (value) capture(this.command) } }
  }
  installFunctions(state, panelSource, ["mainPaneFocusTarget", "restorePaneFocus",
    "launchTerminalAction", "createNode", "createShellOnNode", "updateNode",
    "reauthenticateNode", "startLocalUpdate", "openBoomuxConfig", "requestPluginUpdate",
    "requestUninstallNode", "confirmAction", "cancelConfirmation", "requestRename",
    "cancelRename", "closeActionMenu", "cancelForm", "showSettings", "hideSettings", "showForm",
    "openFreshProjectChooser", "openDirectoryPicker", "closeDirectoryPicker", "chooseDirectory",
    "requestWorkspaceDefaultPath", "workspaceCanChangeDefaultPath",
    "focusPane"])
  const confirmationChange = panelSource.match(/onConfirmationTargetChanged: ([^\n]+)/)[1]
  const renameChange = vm.runInContext("(" + extractBlock(panelSource,
    "onRenameTargetChanged: Qt.callLater(function()").replace(
    "onRenameTargetChanged: Qt.callLater(", "") + ")", state)
  let confirmation = null, rename = null
  Object.defineProperties(state, {
    confirmationTarget: { get: () => confirmation, set(value) {
      confirmation = value; vm.runInContext(confirmationChange, state)
    } },
    renameTarget: { get: () => rename, set(value) { rename = value; Qt.callLater(renameChange) } }
  })
  function flush() {
    let steps = 0
    while (queue.length) {
      if (++steps > 100) throw new Error("Unbounded deferred work")
      queue.shift()()
    }
  }
  function keyHandler(id, name) {
    const tail = panelSource.slice(panelSource.indexOf("id: " + id))
    const marker = "Keys." + name + ": "
    const start = tail.indexOf(marker) + marker.length
    if (start < marker.length) throw new Error("Missing handler for " + id)
    const code = tail.slice(start)
    if (code.startsWith("function(")) return vm.runInContext("(" + extractBlock(code, "function(") + ")", state)
    if (code.startsWith("{")) return vm.runInContext("(function(event) " + extractBlock(code, "{") + ")", state)
    return vm.runInContext("(function(event) { " + code.split("\n")[0] + " })", state)
  }
  return { state, pane, queue, launches, focusHistory, flush, keyHandler,
    get activeFocus() { return activeFocus } }
}

const remote = { node_id: "remote;$(literal)", alias: "Remote", local: false }
const actions = [
  ["Create Node", h => h.state.createNode(), "omarchy-launch-tui --app-id=TUI.float boomux __guided-node-add"],
  ["config editor", h => h.state.openBoomuxConfig(), "omarchy-launch-tui --app-id=TUI.float boomux config edit"],
  ["remote Shell", h => h.state.createShellOnNode(remote), ["boomux", "shell", "create", "workspace-1", "--node", remote.node_id, "--open"]],
  ["remote update", h => h.state.updateNode(remote), model.guidedNodeUpgradeCommand(remote.node_id)],
  ["reauthentication", h => h.state.reauthenticateNode(remote), model.guidedNodeReauthenticateCommand(remote.node_id)],
  ["local update", h => h.state.startLocalUpdate(), model.guidedLocalUpdateCommand()],
  ["plugin update", h => { h.state.requestPluginUpdate(); h.state.confirmAction() }, model.guidedPluginUpdateCommand()],
  ["remote uninstall", h => { h.state.requestUninstallNode(remote); h.state.confirmAction() }, model.guidedNodeUninstallCommand(remote.node_id)]
]

describe("guided terminal keyboard handoff", () => {
  for (const [name, invoke, command] of actions) {
    for (const keyboard of [false, true]) test(name + " from " + (keyboard ? "keyboard" : "pointer") + " mode", () => {
      const h = createHarness()
      h.pane.keyboardMode = keyboard
      h.state.sessionRail.keyboardMode = true
      invoke(h)
      expect(h.launches).toHaveLength(0)
      expect(h.pane.keyboardMode).toBe(false)
      expect(h.state.sessionRail.keyboardMode).toBe(false)
      expect(h.state.terminalLaunchPending).toBe(true)
      h.flush()
      expect(h.launches).toEqual([{ command, keyboardMode: false, railKeyboardMode: false, opened: true }])
      expect(h.state.terminalLaunchPending).toBe(false)
      // Already scheduled modal-focus callbacks must not reclaim keyboard input.
      expect(h.focusHistory).toHaveLength(0)
    })
  }

  test("duplicate launches and focus reentry cannot race the deferred handoff", () => {
    const h = createHarness()
    h.state.updateNode(remote)
    h.state.updateNode({ ...remote, alias: "Other", node_id: "other" })
    h.state.focusPane()
    h.pane.enterKeyboardMode()
    h.flush()
    expect(h.launches).toHaveLength(1)
    expect(h.launches[0].command).toEqual(model.guidedNodeUpgradeCommand(remote.node_id))
    expect(h.state.nodeUpgradeAlias).toBe("Remote")
    expect(h.pane.keyboardMode).toBe(false)
    expect(h.focusHistory).toHaveLength(0)
  })

  test("a failed launcher clears the transient handoff guard", () => {
    const h = createHarness()
    h.state.bar.run = () => { throw new Error("launcher unavailable") }
    h.state.createNode()
    expect(() => h.flush()).toThrow("launcher unavailable")
    expect(h.state.terminalLaunchPending).toBe(false)
    expect(h.pane.keyboardMode).toBe(false)
    expect(h.state.opened).toBe(true)
  })

  test("ineligible remote actions do not launch or release input", () => {
    const h = createHarness()
    h.pane.keyboardMode = true
    h.state.nodeCanUpgrade = () => false
    h.state.nodeCanUninstall = () => false
    h.state.nodeCanReauthenticate = () => false
    h.state.nodeIsActionable = () => false
    h.state.updateNode(remote)
    h.state.requestUninstallNode(remote)
    h.state.reauthenticateNode(remote)
    h.state.createShellOnNode(remote)
    h.flush()
    expect(h.launches).toHaveLength(0)
    expect(h.pane.keyboardMode).toBe(true)
  })
})

describe("interrupted editor keyboard focus", () => {
  test("the live pane binds the state-aware target and transient handoff guard", () => {
    expect(panelSource).toContain("focusTarget: root.mainPaneFocusTarget()")
    expect(panelSource.match(/keyboardModeBlocked: root.terminalLaunchPending/g)).toHaveLength(2)
    expect(panelSource).toContain("onConfirmationTargetChanged: Qt.callLater(root.restorePaneFocus)")
    expect(panelSource).toContain("blocked: root.editing || root.settingsOpen || root.renameTarget !== null")
  })

  const surfaces = [
    ["Rename", h => h.state.requestRename({ kind: "shell", name: "before" }), "renameField", "renameField"],
    ["Create Shell", h => h.state.showForm("shell"), "nameField", "nameField"],
    ["project picker", h => h.state.openFreshProjectChooser(), "projectSearchField", "projectSearchField"],
    ["directory picker", h => { h.state.showForm("shell"); h.state.openDirectoryPicker() }, "directoryPickerKeyHandler", "directoryPickerKeyHandler"],
    ["Settings", h => h.state.showSettings(), "settingsBackButton", "settingsScroll"]
  ]
  for (const [name, show, target, escapeOwner] of surfaces) {
    for (const release of ["outside click", "focus shortcut", "releaseFocus IPC"]) test(name + " resumes after " + release, () => {
      const h = createHarness()
      show(h)
      h.flush()
      expect(h.activeFocus).toBe(target)
      h.state[target].text = "edited draft"
      // Execute the same release paths as outsideClicked and the IPC methods.
      if (release === "focus shortcut") h.state.focusPane()
      else {
        if (release === "releaseFocus IPC") h.state.sessionRail.exitKeyboardMode()
        h.pane.exitKeyboardMode()
      }
      expect(h.pane.keyboardMode).toBe(false)
      h.state.focusPane()
      h.flush()
      expect(h.activeFocus).toBe(target)
      expect(h.state[target].text).toBe("edited draft")
      const handler = h.keyHandler(escapeOwner, target === "directoryPickerKeyHandler" ? "onPressed" : "onEscapePressed")
      handler({ key: "Escape", accepted: false })
      h.flush()
      expect(h.state.opened).toBe(true)
      expect(h.activeFocus).toBe(target === "directoryPickerKeyHandler" ? "browseButton" : "keyCatcher")
      if (target === "renameField") expect(h.state.renameTarget).toBeNull()
      else if (target === "settingsBackButton") expect(h.state.settingsOpen).toBe(false)
      else if (target === "directoryPickerKeyHandler") expect(h.state.directoryPickerOpen).toBe(false)
      else expect(h.state.formMode).toBe("")
    })
  }

  test("Rename survives close/reopen with its draft and receives Escape", () => {
    const h = createHarness()
    h.state.requestRename({ kind: "shell", name: "before" })
    h.flush()
    h.state.renameField.text = "edited draft"
    h.state.opened = false
    h.pane.exitKeyboardMode()
    h.state.cancelForm()
    h.flush()
    h.state.focusPane()
    h.flush()
    expect(h.activeFocus).toBe("renameField")
    expect(h.state.renameField.text).toBe("edited draft")
    h.keyHandler("renameField", "onEscapePressed")({ key: "Escape" })
    h.flush()
    expect(h.state.renameTarget).toBeNull()
    expect(h.activeFocus).toBe("keyCatcher")
  })

  test("the Workspace default-directory picker resumes and Escape cancels the whole form", () => {
    const h = createHarness()
    h.state.workspaceDefaultCwdSupported = true
    h.state.daemonProtocolVersion = 49
    h.state.workspaceMutationBusy = () => false
    h.state.nodes = [{ node_id: "local", local: true, current: true, stale: false, health: "online" }]
    h.state.requestWorkspaceDefaultPath({ key: "workspace", id: "workspace", is_global: true,
      placements: [{ node_id: "local", workspace_id: "owner", state: "active", available: true, default_cwd: "/tmp" }] })
    h.flush()
    expect(h.activeFocus).toBe("directoryPickerKeyHandler")
    h.pane.exitKeyboardMode()
    h.state.focusPane()
    h.flush()
    expect(h.activeFocus).toBe("directoryPickerKeyHandler")
    h.keyHandler("directoryPickerKeyHandler", "onPressed")({ key: "Escape" })
    h.flush()
    expect(h.state.formMode).toBe("")
    expect(h.state.defaultPathTarget).toBeNull()
    expect(h.activeFocus).toBe("keyCatcher")
  })

  test("a newer surface wins over deferred entry and dismissal callbacks", () => {
    const h = createHarness()
    h.state.showForm("shell")
    h.state.openDirectoryPicker()
    h.state.closeDirectoryPicker()
    h.state.showSettings()
    h.flush()
    expect(h.activeFocus).toBe("settingsBackButton")
    expect(h.focusHistory.every(name => name === "settingsBackButton")).toBe(true)
  })

  test("focus callbacks do nothing after release or close", () => {
    for (const close of [false, true]) {
      const h = createHarness()
      h.state.showSettings()
      if (close) h.state.opened = false
      else h.pane.exitKeyboardMode()
      h.flush()
      expect(h.focusHistory).toHaveLength(0)
    }
  })

  test("invalid or disabled targets are never force-focused", () => {
    for (const flag of ["visible", "enabled"]) {
      const h = createHarness()
      h.state.showSettings()
      h.state.settingsBackButton[flag] = false
      h.flush()
      expect(h.focusHistory).toHaveLength(0)
    }
  })

  test("confirmation wins over the editor and restores it on Escape", () => {
    const h = createHarness()
    h.state.showForm("shell")
    h.state.requestUninstallNode(remote)
    h.flush()
    expect(h.activeFocus).toBe("confirmationDialogKeyHandler")
    h.state.cancelConfirmation()
    h.flush()
    expect(h.activeFocus).toBe("nameField")
  })

  test("Escape from form buttons closes the correct surface after Tab", () => {
    const h = createHarness()
    h.state.openFreshProjectChooser()
    h.flush()
    h.keyHandler("projectSearchField", "onTabPressed")({ key: "Tab" })
    expect(h.activeFocus).toBe("projectCancelButton")
    h.keyHandler("formColumn", "onEscapePressed")({ key: "Escape" })
    h.flush()
    expect(h.state.formMode).toBe("")
    expect(h.activeFocus).toBe("keyCatcher")
    h.state.showForm("shell")
    h.state.openDirectoryPicker()
    h.flush()
    h.keyHandler("directoryPickerKeyHandler", "onPressed")({ key: "Tab" })
    expect(h.activeFocus).toBe("directoryChooseButton")
    h.keyHandler("formColumn", "onEscapePressed")({ key: "Escape" })
    h.flush()
    expect(h.state.directoryPickerOpen).toBe(false)
    expect(h.state.formMode).toBe("shell")
    expect(h.activeFocus).toBe("browseButton")
  })
})
