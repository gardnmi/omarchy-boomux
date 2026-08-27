import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Ui
import "WorkspaceModel.js" as WorkspaceModel

Panel {
  id: root

  moduleName: "io.github.gardnmi.boomux"
  ipcTarget: "io.github.gardnmi.boomux"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color keyboardCursorFill: Util.alpha(foreground, 0.065)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string boomuxRepositoryUrl: "https://github.com/gardnmi/boomux"
  readonly property string pluginRepositoryUrl: "https://github.com/gardnmi/omarchy-boomux"
  readonly property string paneSide: String(setting("side", "left")).toLowerCase() === "right"
    ? "right" : "left"
  readonly property int paneWidth: Math.max(Style.space(280),
    Math.min(Style.space(520), Number(setting("paneWidth", Style.space(360)))))

  property var workspaces: []
  property var workspaceTreeWorkspaces: []
  property string workspaceTreeSnapshotSignature: ""
  property var shells: []
  property var agents: []
  property var nodes: []
  property var projects: []
  property var workspaceDetail: null
  property string selectedWorkspaceKey: ""
  property string selectedNodeId: ""
  property string selectedAgentKey: ""
  property string activeTab: "agents"
  property string expandedWorkspaceKey: ""
  property string pendingWorkspacePositionKey: ""
  property int workspaceTreeHeight: Style.space(340)
  property int selectedIndex: 0
  property bool online: false
  property bool refreshing: false
  property int refreshPending: 0
  property bool capabilitiesReady: false
  property bool cliAvailable: false
  property string cliVersion: ""
  property string latestBoomuxVersion: ""
  property string latestBoomuxUrl: ""
  property string boomuxUpdateAction: ""
  property bool localUpdateVerificationPending: false
  property int localUpdateVerificationAttempts: 0
  property string localUpdateExpectedVersion: ""
  property string pluginVersion: ""
  property string latestPluginVersion: ""
  readonly property bool boomuxUpdateAvailable:
    WorkspaceModel.versionIsNewer(latestBoomuxVersion, cliVersion)
  readonly property bool pluginUpdateAvailable:
    WorkspaceModel.versionIsNewer(latestPluginVersion, pluginVersion)
  readonly property bool updateAvailable: boomuxUpdateAvailable || pluginUpdateAvailable
  property bool federationSupported: false
  property bool globalWorkspacesSupported: false
  property var cliFeatures: []
  property bool projectListSupported: false
  property bool atomicWorkspaceCreationSupported: false
  property bool workspaceDefaultCwdSupported: false
  property bool integrationStatusSupported: false
  property bool localUpdateStatusSupported: false
  property bool guidedLocalUpdateSupported: false
  property bool shellNameSuggestionSupported: false
  property bool webLifecycleSupported: false
  property bool focusEventsSupported: false
  property bool workspaceSelectionSupported: false
  property bool webRunning: false
  property bool webTailscale: false
  property string webDashboardUrl: ""
  property string webOpencodeUrl: ""
  property bool projectRootsConfigured: false
  property bool projectDiscoveryLoaded: false
  property string projectLoadedNodeId: ""
  property bool projectChooserRequested: false
  property double projectDiscoveryExpiresAt: 0
  property bool projectRefreshQueued: false
  property int daemonProtocolVersion: 0
  property bool agentBaselineReady: false
  property var previousAgentStates: ({})
  property var completedAgents: ({})
  property var acknowledgeQueue: []
  property var activeAcknowledgement: null
  property var automaticAttentionRevisions: ({})
  property var pendingOpenAgent: null
  property string pendingOpenKey: ""
  property string pendingOpenRunKey: ""
  property var itemToRemove: null
  property var actionMenuTarget: null
  property real actionMenuX: 0
  property real actionMenuY: 0
  property real actionMenuAnchorY: 0
  property int actionMenuIndex: 0
  property string focusSection: "workspaces"
  property int selectedWorkspaceIndex: 0
  property int selectedWorkspaceItemIndex: 0
  property var renameTarget: null
  property string renameError: ""
  property string inspectRequestedKey: ""
  property string inspectActiveKey: ""
  property string error: ""
  property string actionMessage: ""
  property string nodeShellAlias: ""
  property string nodeUpgradeAlias: ""
  property string nodeUninstallAlias: ""
  property string nodeReauthenticateAlias: ""
  property string formMode: ""
  property bool settingsOpen: false
  property string projectQuery: ""
  property int selectedProjectIndex: -1
  property string projectError: ""
  property bool cwdIsExact: false
  property bool nameFieldEdited: false
  property var suggestedNameRequestedIdentity: null
  property var suggestedNameActiveIdentity: null
  property bool directoryPickerOpen: false
  property string directoryPickerPath: ""
  property int directoryPickerIndex: 0
  property string directoryPickerPurpose: "resource"
  property var agentHosts: []
  property string agentHostName: ""
  property var agentHostCommand: []
  property string agentHostError: ""
  property string agentHostRequestedNodeId: ""
  property string agentHostActiveNodeId: ""
  property var pendingAction: null
  property var pendingWorkspaceOpen: null
  property var workspaceCreateRequested: null
  property bool workspaceCreateStatusQueued: false
  property bool workspaceCreateStatusActive: false
  property bool workspaceCreateSnapshotQueued: false
  property bool workspaceCreateSnapshotActive: false
  property var pendingWorkspaceCreation: null
  property double pendingWorkspaceConfirmationDeadline: 0
  property var defaultPathTarget: null
  property var defaultCwdRequest: null
  property var pendingDefaultCwd: null
  property double pendingDefaultCwdConfirmationDeadline: 0
  property var pendingShell: null
  property string projectRequestedNodeId: ""
  property string projectActiveNodeId: ""
  property string creationNodeId: ""
  property int pollEpoch: 0
  property int snapshotActiveEpoch: 0
  property double clockNow: Date.now()
  property double focusedTerminalRevision: 0
  property string focusedTerminalKey: ""
  property string noticeTitle: ""
  property string noticeDetail: ""
  property var noticeScreen: null
  property bool noticeVisible: false
  property double noticeProtectedUntil: 0
  property string eventCursor: ""
  property bool focusRefreshPending: false
  property var workspaceSelectionRequested: null
  property var workspaceSelectionActive: null
  property string workspaceSelectionAppliedId: ""
  property string activeBoomuxWorkspaceId: ""
  property bool desktopWorkspaceRefreshPending: false
  property string activeBoomuxTerminalKey: ""
  property bool desktopTerminalRefreshPending: false

  readonly property var visibleWorkspaces: workspaces
  readonly property var visibleNodes: nodes.filter(function(node) { return !node.local })
  readonly property var visibleAgents: WorkspaceModel.agentsByLastUpdated(agents.filter(function(agent) {
    var state = agent.observation ? agent.observation.state : "unknown"
    return !agentHasPrivateOwner(agent)
      && ((agentIsProjectedCurrent(agent) && state !== "inactive" && state !== "done")
        || attentionRevision(agent) > 0)
  }))
  readonly property var paneAgents: visibleAgents
  readonly property var cursorWorkspace: selectedWorkspaceIndex >= 0
    && selectedWorkspaceIndex < workspaceTreeWorkspaces.length
    ? workspaceTreeWorkspaces[selectedWorkspaceIndex] : null
  readonly property var cursorWorkspaceItems: cursorWorkspace
    ? WorkspaceModel.workspaceTreeItems(cursorWorkspace) : []
  readonly property var cursorWorkspaceItem: selectedWorkspaceItemIndex >= 0
    && selectedWorkspaceItemIndex < cursorWorkspaceItems.length
    ? cursorWorkspaceItems[selectedWorkspaceItemIndex] : null
  readonly property var currentActionMenuActions: actionMenuActionsFor(actionMenuTarget)
  readonly property string currentActionMenuAction: actionMenuIndex >= 0
    && actionMenuIndex < currentActionMenuActions.length
    ? currentActionMenuActions[actionMenuIndex] : ""
  readonly property var selectedWorkspace: {
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === selectedWorkspaceKey) return workspaces[i]
    return null
  }
  readonly property var activeBoomuxWorkspace: {
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].is_global && workspaces[i].id === activeBoomuxWorkspaceId)
        return workspaces[i]
    return null
  }
  readonly property string activeBoomuxWorkspaceName: activeBoomuxWorkspace
    ? String(activeBoomuxWorkspace.name) : ""
  readonly property var activeBoomuxTerminal: {
    for (var i = 0; i < shells.length; i++)
      if (shells[i].key === activeBoomuxTerminalKey) return shells[i]
    return null
  }
  readonly property var activeBoomuxTerminalWorkspace: {
    var key = activeBoomuxTerminal ? activeBoomuxTerminal.workspace_key : ""
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === key) return workspaces[i]
    return null
  }
  readonly property string activeBoomuxTerminalLabel: {
    if (!activeBoomuxTerminal || !activeBoomuxTerminalWorkspace) return ""
    var shellName = String(activeBoomuxTerminal.name)
    return activeBoomuxTerminalWorkspace.id === activeBoomuxWorkspaceId
      ? "> " + shellName
      : "> " + String(activeBoomuxTerminalWorkspace.name) + " / " + shellName
  }
  readonly property bool federationAvailable: federationSupported && daemonProtocolVersion >= 33
  readonly property bool globalWorkspacesAvailable: globalWorkspacesSupported
    && daemonProtocolVersion >= 38
  readonly property var eligibleCreationNodes: WorkspaceModel.eligibleNodes(nodes)
  readonly property var creationNode: {
    if (!globalWorkspacesAvailable) return selectedCreationNode()
    var selected = nodeFor(creationNodeId)
    return selected && selected.workspace_owner_eligible ? selected : null
  }
  readonly property var visibleProjects: filterProjects()
  readonly property var selectedProject: selectedProjectIndex >= 0
    && selectedProjectIndex < visibleProjects.length ? visibleProjects[selectedProjectIndex] : null
  readonly property bool directoryPickerCanGoUp: directoryPickerPath !== ""
    && directoryPickerPath !== "/"
  readonly property int itemCount: activeTab === "agents" ? paneAgents.length : visibleNodes.length
  readonly property var selectedItem: {
    var model = activeTab === "agents" ? paneAgents : visibleNodes
    return selectedIndex >= 0 && selectedIndex < model.length ? model[selectedIndex] : null
  }
  readonly property var selectedNode: {
    for (var i = 0; i < nodes.length; i++)
      if (nodes[i].node_id === selectedNodeId) return nodes[i]
    return null
  }
  readonly property int blockedCount: visibleAgents.filter(function(agent) {
    return agentNeedsAttention(agent)
  }).length
  readonly property int workingCount: visibleAgents.filter(function(agent) {
    return agent.observation && agent.observation.state === "working"
  }).length
  readonly property int completedCount: countCompletedAgents()
  readonly property bool editing: formMode !== ""

  onProjectQueryChanged: {
    selectedProjectIndex = -1
    clampProjectSelection()
  }

  onAgentHostNameChanged: if (agentHostDropdown)
    agentHostDropdown.value = agentHostName

  onItemToRemoveChanged: Qt.callLater(function() {
    if (itemToRemove) removeDialogKeyHandler.forceActiveFocus()
    else if (opened) keyCatcher.forceActiveFocus()
  })

  onRenameTargetChanged: Qt.callLater(function() {
    if (renameTarget) {
      renameField.text = renameTarget.kind === "workspace"
        ? String(renameTarget.workspace.name) : String(renameTarget.name)
      renameField.selectAll()
      renameField.forceActiveFocus()
    } else if (opened) keyCatcher.forceActiveFocus()
  })

  visible: true
  implicitWidth: desktopIndicator.implicitWidth
  implicitHeight: desktopIndicator.implicitHeight

  Component.onCompleted: {
    try {
      pluginVersion = String(JSON.parse(pluginManifest.text()).version || "")
    } catch (exception) {
      pluginVersion = ""
    }
    capabilityProcess.running = true
    pluginUpdateProcess.running = true
    desktopWorkspaceProcess.running = true
    desktopTerminalProcess.running = true
  }

  function parseDesktopWorkspaceMonitors(text) {
    try {
      var monitors = JSON.parse(text)
      for (var i = 0; i < monitors.length; i++) {
        if (!monitors[i].focused) continue
        var special = monitors[i].specialWorkspace
        activeBoomuxWorkspaceId = WorkspaceModel.boomuxSpecialWorkspaceId(
          special ? special.name : "")
        return
      }
    } catch (exception) {
    }
    activeBoomuxWorkspaceId = ""
  }

  function refreshDesktopWorkspace() {
    if (desktopWorkspaceProcess.running) {
      desktopWorkspaceRefreshPending = true
      return
    }
    desktopWorkspaceProcess.running = true
  }

  function parseDesktopTerminal(text) {
    try {
      var window = JSON.parse(text)
      activeBoomuxTerminalKey = WorkspaceModel.boomuxShellWindowKey(
        window.initialTitle, focusedTerminalKey, shells)
      return
    } catch (exception) {
    }
    activeBoomuxTerminalKey = ""
  }

  function refreshDesktopTerminal() {
    if (desktopTerminalProcess.running) {
      desktopTerminalRefreshPending = true
      return
    }
    desktopTerminalProcess.running = true
  }

  function resourceId(value) {
    return value && typeof value === "object" ? String(value.inner_id || "") : String(value || "")
  }

  function resourceNode(value, fallback) {
    return value && typeof value === "object" ? String(value.node_id || fallback || "")
      : String(fallback || "")
  }

  function resourceKey(nodeId, value) {
    return String(nodeId || "") + "\u001f" + resourceId(value)
  }

  function nodeFor(nodeId) {
    for (var i = 0; i < nodes.length; i++) if (nodes[i].node_id === nodeId) return nodes[i]
    return null
  }

  function nodeIsActionable(nodeId, capability) {
    var node = nodeFor(nodeId)
    if (!node) return !federationAvailable && nodeId === "local"
    if (!node.current || node.stale || node.health !== "online") return false
    if (node.local || !capability) return true
    return cliFeatures.indexOf(capability) >= 0
      && node.observed_capabilities.indexOf(capability) >= 0
  }

  function nodeArgs(nodeId, capability) {
    var node = nodeFor(nodeId)
    if (!node || node.local) return []
    return nodeIsActionable(nodeId, capability) ? ["--node", nodeId] : null
  }

  function resourceIsActionable(resource, capability) {
    return WorkspaceModel.resourceActionable(resource,
      resource && nodeIsActionable(resource.node_id, capability))
  }

  function selectedCreationNode() {
    if (globalWorkspacesAvailable) return creationNode
    for (var i = 0; i < nodes.length; i++) if (nodes[i].local) return nodes[i]
    return { node_id: "local", alias: "local", local: true, current: online, stale: false }
  }

  function nodeName(item) {
    return String(item && item.node_alias ? item.node_alias : "local")
  }

  function workspaceOwnershipLabel(workspace) {
    if (!workspace) return ""
    if (workspace.is_global) return workspace.placements.length + " placement"
      + (workspace.placements.length === 1 ? "" : "s")
    return "Node: " + nodeName(workspace)
      + (workspace.is_external ? " · external Workspace" : "")
  }

  function workspaceVisibleAgentCount(workspace) {
    if (!workspace) return 0
    return paneAgents.filter(function(agent) {
      return workspace.is_global
        ? String(agent.global_workspace_id || "") === String(workspace.id)
        : agent.workspace_key === workspace.key
    }).length
  }

  function nodeHealthLabel(node) {
    if (!node) return "unknown"
    return String(node.health).split("_").join(" ") + (node.stale ? " · stale cache" : "")
  }

  function nodeHealthColor(node) {
    if (!node) return dim
    if (node.health === "online" && node.current && !node.stale) return Color.accent
    if (node.health === "authentication_required" || node.health === "identity_changed"
        || node.health === "identity_conflict" || node.health === "unsupported"
        || node.health === "unreachable") return urgent
    return dim
  }

  function nodeHealthDetail(node) {
    if (!node) return "unknown"
    if (node.health === "authentication_required")
      return "authentication required · cached data retained · retrying automatically"
    if (node.health === "reconnecting")
      return "reconnecting · cached data retained · retrying automatically"
    if (node.health === "stale" || node.health === "unreachable" || node.stale)
      return String(node.health).split("_").join(" ")
        + " · cached data retained · retrying automatically"
    if (node.health === "identity_changed" || node.health === "identity_conflict")
      return String(node.health).split("_").join(" ")
        + " · cached data retained · action required"
    return nodeHealthLabel(node)
  }

  function nodeNextStep(node) {
    if (!node) return ""
    if (nodeCanReauthenticate(node)) return "Open Node actions and choose Authenticate."
    if (nodeCanUpgrade(node)) return "Open Node actions and choose Update."
    if (node.health === "identity_changed" || node.health === "identity_conflict")
      return "Open the Boomux TUI to review and repair the registered identity."
    if (nodeVersionDirection(node) === "newer")
      return "Update Boomux on this control machine before managing the Node."
    return ""
  }

  function nodeVersionDirection(node) {
    return WorkspaceModel.versionDirection(node ? node.observed_helper_version : "", cliVersion)
  }

  function nodeCanUpgrade(node) {
    return WorkspaceModel.nodeCanUpgrade(node, cliVersion, cliFeatures)
  }

  function nodeCanUninstall(node) {
    return WorkspaceModel.nodeCanUninstall(node, cliFeatures, daemonProtocolVersion)
  }

  function nodeCanReauthenticate(node) {
    return WorkspaceModel.nodeCanReauthenticate(node, cliFeatures, daemonProtocolVersion)
  }

  function nodeVersionIndicator(node) {
    if (!node || !node.observed_helper_version) return "unknown"
    var remote = String(node.observed_helper_version)
    var direction = nodeVersionDirection(node)
    if (direction === "older") return remote + " → " + cliVersion
    if (direction === "newer") return remote + " · control old"
    return remote
  }

  function nodeRuntimeSummary(node) {
    if (!node) return ""
    var version = node.observed_helper_version
      ? String(node.observed_helper_version) : "version unknown"
    return version + " · protocol " + Number(node.observed_protocol_version || 0)
      + " · seen " + formatTimestamp(node.observed_at_ms)
  }

  function nodeWorkloadSummary(node) {
    if (!node) return ""
    return nodeWorkspaceCount(node) + " Workspaces · " + nodeShellCount(node) + " Shells · "
      + nodeAgentCount(node) + " Agents"
  }

  function nodeMetric(node, field, collection) {
    if (!node) return 0
    if (node[field] !== undefined) return Number(node[field] || 0)
    return collection.filter(function(item) { return item.node_id === node.node_id }).length
  }

  function nodeWorkspaceCount(node) {
    return nodeMetric(node, "workspace_count", workspaces)
  }

  function nodeShellCount(node) {
    if (!node) return 0
    if (node && node.shell_count !== undefined) return Number(node.shell_count || 0)
    return shells.filter(function(shell) {
      return shell.node_id === node.node_id && shellOwner(shell.owner) !== "schedule"
    }).length
  }

  function nodeAgentCount(node) {
    if (!node) return 0
    return visibleAgents.filter(function(agent) { return agent.node_id === node.node_id }).length
  }

  function shellOwner(owner) {
    if (typeof owner === "string") return owner
    return owner && owner.kind === "schedule" ? "schedule" : "user"
  }

  function refresh() {
    if (capabilitiesReady && !cliAvailable) return
    if (opened && activeTab === "agents" && webLifecycleSupported
        && !webStatusProcess.running && !webStartProcess.running && !webStopProcess.running)
      webStatusProcess.running = true
    if (daemonStatusProcess.running) return
    daemonStatusProcess.running = true
  }

  function refreshInstalledState() {
    invalidateProjectDiscovery()
    if (!capabilityProcess.running) capabilityProcess.running = true
    refresh()
  }

  function refreshData() {
    if (nodeSnapshotProcess.running || workspaceListProcess.running || listProcess.running
        || agentProcess.running) return
    if (federationAvailable) {
      refreshing = true
      refreshPending = 1
      error = ""
      snapshotActiveEpoch = pollEpoch
      nodeSnapshotProcess.running = true
      return
    }
    refreshing = true
    refreshPending = 3
    error = ""
    workspaceListProcess.running = true
    listProcess.running = true
  }

  function setOffline(message) {
    pollEpoch++
    eventCursor = ""
    focusRefreshPending = false
    if (eventProcess.running) eventProcess.running = false
    online = false
    refreshing = false
    workspaceTreeSnapshotSignature = ""
    workspaces = []
    workspaceTreeWorkspaces = []
    shells = []
    agents = []
    nodes = []
    workspaceDetail = null
    selectedWorkspaceKey = ""
    selectedNodeId = ""
    selectedAgentKey = ""
    itemToRemove = null
    daemonProtocolVersion = 0
    previousAgentStates = ({})
    completedAgents = ({})
    automaticAttentionRevisions = ({})
    agentBaselineReady = false
    invalidateProjectDiscovery()
    if (workspaceCreateRequested && !daemonStartProcess.running) {
      failWorkspaceCreation("Boomux went offline before creation could obtain a fresh Node snapshot")
    }
    if (pendingDefaultCwd) {
      actionMessage = "Shell start folder changed; waiting for Boomux to confirm the snapshot"
    }
    if (pendingWorkspaceCreation) {
      actionMessage = "Workspace created; waiting for Boomux to confirm the snapshot"
    }
    error = message
  }

  function parseDaemonStatus(raw, explicitCreationCheck) {
    try {
      var data = parseEnvelope(raw, "daemon.status")
      if (data.status !== "running") {
        if (explicitCreationCheck && workspaceCreateRequested) {
          actionMessage = "Starting Boomux..."
          daemonStartProcess.running = true
        }
        setOffline("Boomux daemon is stopped")
        return
      }
      daemonProtocolVersion = Number(data.protocol_version || 0)
      if (explicitCreationCheck) requestFreshWorkspaceCreateSnapshot()
      else refreshData()
      startEventWait()
    } catch (exception) {
      if (explicitCreationCheck)
        failWorkspaceCreation("Could not validate Boomux daemon status before creation")
      else setOffline("Boomux daemon is stopped")
    }
  }

  function parseEnvelope(raw, command) {
    return WorkspaceModel.parseEnvelope(String(raw || ""), command)
  }

  function parseCapabilities(raw) {
    cliAvailable = true
    try {
      var data = parseEnvelope(raw, "capabilities")
      if (!Array.isArray(data.json_commands)) throw new Error("missing JSON commands")
      cliVersion = String(data.cli_version || "")
      cliFeatures = Array.isArray(data.features) ? data.features : []
      projectListSupported = data.json_commands.indexOf("project.list") >= 0
      atomicWorkspaceCreationSupported = data.json_commands.indexOf("workspace.create") >= 0
        && cliFeatures.indexOf("atomic_workspace_shell_creation") >= 0
      workspaceDefaultCwdSupported = data.json_commands.indexOf("workspace.set-default-cwd") >= 0
        && cliFeatures.indexOf("workspace_placement_default_cwd") >= 0
      integrationStatusSupported = data.json_commands.indexOf("integration.status") >= 0
      localUpdateStatusSupported = data.json_commands.indexOf("update.status") >= 0
        && cliFeatures.indexOf("local_update_status") >= 0
      guidedLocalUpdateSupported = cliFeatures.indexOf("guided_local_update") >= 0
      shellNameSuggestionSupported = data.json_commands.indexOf("shell.suggest-name") >= 0
      webLifecycleSupported = ["web.start", "web.status", "web.stop"].every(function(command) {
        return data.json_commands.indexOf(command) >= 0
      })
      focusEventsSupported = data.json_commands.indexOf("events") >= 0
        && cliFeatures.indexOf("qualified_focused_terminal") >= 0
      workspaceSelectionSupported = cliFeatures.indexOf("persistent_workspace_selection") >= 0
        && cliFeatures.indexOf("create_and_open_shell") >= 0
      federationSupported = data.json_commands.indexOf("node.snapshot") >= 0
        && cliFeatures.indexOf("combined_node_snapshot") >= 0
        && cliFeatures.indexOf("node_qualified_dashboard") >= 0
        && cliFeatures.indexOf("typed_exact_node_routing") >= 0
      globalWorkspacesSupported = federationSupported
        && cliFeatures.indexOf("global_workspaces") >= 0
        && cliFeatures.indexOf("multi_node_workspace_placements") >= 0
      if (localUpdateStatusSupported) localUpdateStatusProcess.running = true
      else boomuxUpdateProcess.running = true
    } catch (exception) {
      cliVersion = ""
      projectListSupported = false
      atomicWorkspaceCreationSupported = false
      workspaceDefaultCwdSupported = false
      integrationStatusSupported = false
      localUpdateStatusSupported = false
      guidedLocalUpdateSupported = false
      shellNameSuggestionSupported = false
      webLifecycleSupported = false
      focusEventsSupported = false
      workspaceSelectionSupported = false
      webRunning = false
      webTailscale = false
      webDashboardUrl = ""
      webOpencodeUrl = ""
      federationSupported = false
      globalWorkspacesSupported = false
      cliFeatures = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
    capabilitiesReady = true
  }

  function normalizeAgent(source, node, workspaceName) {
    return WorkspaceModel.normalizeAgent(source, node, workspaceName)
  }

  function parseNodeSnapshot(raw, explicitCreationSnapshot) {
    try {
      if (snapshotActiveEpoch !== pollEpoch) {
        if (explicitCreationSnapshot)
          failWorkspaceCreation("Boomux state changed before the fresh Node snapshot completed")
        return
      }
      var treeScrollY = workspaceTreeList ? workspaceTreeList.contentY : 0
      var data = parseEnvelope(raw, "node.snapshot")
      var snapshot = WorkspaceModel.normalizeNodeSnapshot(data)
      nodes = snapshot.nodes
      var workspaceModelChanged = applyWorkspaceSnapshot(snapshot.workspaces)
      shells = snapshot.shells
      updateFocusedTerminal(snapshot.focused_terminal)
      refreshDesktopTerminal()
      applyAgentSnapshot(snapshot.agents)
      online = true
      preserveSelections()
      if (workspaceModelChanged) restoreWorkspaceTreeScroll(treeScrollY)
      openPendingShellIfPresent()
      resolvePendingWorkspaceCreation()
      resolvePendingDefaultCwd()
      ensureLocalProjectDiscovery()
      if (explicitCreationSnapshot) maybeStartWorkspaceCreation()
      scheduleMutationConfirmation()
    } catch (exception) {
      if (explicitCreationSnapshot) {
        failWorkspaceCreation("Could not validate the fresh Boomux Node snapshot")
        return
      }
      error = "Could not read federated Boomux state"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function applyWorkspaceSnapshot(nextWorkspaces) {
    var cursorKey = cursorWorkspace ? cursorWorkspace.key : ""
    workspaces = nextWorkspaces
    var signature = WorkspaceModel.workspaceTreeModelSignature(nextWorkspaces)
    if (signature === workspaceTreeSnapshotSignature) return false
    workspaceTreeSnapshotSignature = signature
    workspaceTreeWorkspaces = nextWorkspaces
    if (cursorKey !== "") for (var i = 0; i < nextWorkspaces.length; i++) {
      if (nextWorkspaces[i].key === cursorKey) {
        selectedWorkspaceIndex = i
        break
      }
    }
    clampWorkspaceCursor()
    return true
  }

  function restoreWorkspaceTreeScroll(contentY) {
    if (!workspaceTreeList || !opened) return
    Qt.callLater(function() {
      if (root.pendingWorkspacePositionKey !== "") return
      var maximum = Math.max(0,
        workspaceTreeList.contentHeight - workspaceTreeList.height)
      workspaceTreeList.contentY = Math.max(0,
        Math.min(Number(contentY || 0), maximum))
    })
  }

  function updateFocusedTerminal(focused) {
    if (!focused) return
    var key = resourceKey(focused.node_id, focused.shell_id)
    if (focused.revision === focusedTerminalRevision && key === focusedTerminalKey) return
    focusedTerminalRevision = focused.revision
    focusedTerminalKey = key

    var shell = null
    for (var i = 0; i < shells.length; i++) {
      if (shells[i].key === key) {
        shell = shells[i]
        break
      }
    }
    if (!shell || shellOwner(shell.owner) === "schedule") return

    var toplevel = ToplevelManager.activeToplevel
    var screen = toplevel && toplevel.screens.length > 0 ? toplevel.screens[0] : null
    var ownWindow = root.QsWindow ? root.QsWindow.window : null
    if (!screen || !ownWindow || ownWindow.screen !== screen) return

    if (Date.now() < noticeProtectedUntil) return
    showNotice(String(shell.workspace_name), String(shell.name), screen, false)
  }

  function currentNoticeScreen() {
    var ownWindow = root.QsWindow ? root.QsWindow.window : null
    if (ownWindow && ownWindow.screen) return ownWindow.screen
    var toplevel = ToplevelManager.activeToplevel
    return toplevel && toplevel.screens.length > 0 ? toplevel.screens[0] : null
  }

  function showNotice(title, detail, screen, protectedNotice) {
    var targetScreen = screen || currentNoticeScreen()
    if (!targetScreen) return
    noticeTitle = String(title || "")
    noticeDetail = String(detail || "")
    noticeScreen = targetScreen
    noticeVisible = true
    noticeProtectedUntil = protectedNotice ? Date.now() + noticeTimer.interval : 0
    noticeTimer.restart()
  }

  onActionMessageChanged: {
    if (actionMessage !== "")
      showNotice("Boomux", actionMessage, currentNoticeScreen(), true)
  }

  function showActionFailure(title, detail) {
    actionMessage = String(detail || "")
    showNotice(title, actionMessage, currentNoticeScreen(), true)
  }

  function startEventWait() {
    if (!focusEventsSupported || daemonProtocolVersion < 39 || eventProcess.running) return
    eventProcess.command = eventCursor === ""
      ? ["boomux", "events", "--json"]
      : ["boomux", "events", "--after", eventCursor, "--wait-ms", "30000", "--json"]
    eventProcess.running = true
  }

  function parseEvents(raw) {
    var data = parseEnvelope(raw, "events")
    if (typeof data.cursor !== "string" || !Array.isArray(data.events))
      throw new Error("invalid event batch")
    eventCursor = data.cursor
    for (var i = 0; i < data.events.length; i++) {
      if (data.events[i] && data.events[i].event === "focused_terminal_presentation_changed") {
        requestFocusedTerminalRefresh()
        break
      }
    }
  }

  function requestFocusedTerminalRefresh() {
    if (!federationAvailable || daemonProtocolVersion < 39) return
    if (nodeSnapshotProcess.running) {
      focusRefreshPending = true
      return
    }
    snapshotActiveEpoch = pollEpoch
    nodeSnapshotProcess.running = true
  }

  function preserveSelections() {
    if (!selectedWorkspace)
      selectedWorkspaceKey = visibleWorkspaces.length > 0 ? visibleWorkspaces[0].key : ""
    if (!selectedNode)
      selectedNodeId = visibleNodes.length > 0 ? visibleNodes[0].node_id : ""
    workspaceDetail = selectedWorkspace
    syncAgentIndex()
    syncWorkspaceIndex()
    syncNodeIndex()
    clampSelection()
  }

  function parseWorkspaces(raw) {
    try {
      var treeScrollY = workspaceTreeList ? workspaceTreeList.contentY : 0
      var data = parseEnvelope(raw, "workspace.list")
      if (!Array.isArray(data.workspaces)) throw new Error("missing workspaces")
      nodes = [{ node_id: "local", alias: "local", local: true, health: "online",
        current: true, stale: false, observed_capabilities: [] }]
      if (!selectedNode) selectedNodeId = "local"
      var nextWorkspaces = data.workspaces.map(function(workspace) {
        return Object.assign({}, workspace, { key: resourceKey("local", workspace.id),
          node_id: "local", node_alias: "local", node_local: true,
          node_current: true, node_stale: false,
          node_health: "online" })
      })
      var workspaceModelChanged = applyWorkspaceSnapshot(nextWorkspaces)
      online = true

      if (!selectedWorkspace || selectedWorkspaceKey === "")
        selectedWorkspaceKey = workspaces.length > 0 ? workspaces[0].key : ""
      syncWorkspaceIndex()
      if (selectedWorkspaceKey !== "") inspectWorkspace(selectedWorkspaceKey)
      else workspaceDetail = null
      clampSelection()
      if (workspaceModelChanged) restoreWorkspaceTreeScroll(treeScrollY)
    } catch (exception) {
      online = false
      workspaces = []
      workspaceDetail = null
      error = "Could not read Boomux workspaces"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseShells(raw) {
    try {
      var data = parseEnvelope(raw, "list")
      if (!Array.isArray(data.shells)) throw new Error("missing shells")
      shells = data.shells.map(function(shell) {
        return Object.assign({}, shell, { key: resourceKey("local", shell.id), node_id: "local",
          node_alias: "local", node_local: true, node_current: true, node_stale: false,
          workspace_key: resourceKey("local", shell.workspace_id) })
      })
      online = true
    } catch (exception) {
      shells = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function parseAgents(raw) {
    try {
      var data = parseEnvelope(raw, "agent.list")
      if (!Array.isArray(data.agents)) throw new Error("missing agents")
      var localNode = nodes.length > 0 ? nodes[0]
        : { node_id: "local", alias: "local", local: true, current: true, stale: false }
      applyAgentSnapshot(data.agents.map(function(agent) {
        return normalizeAgent(agent, localNode, agent.workspace_name)
      }))
    } catch (exception) {
      agents = []
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function applyAgentSnapshot(nextAgents) {
      var nextStates = ({})
      var nextCompleted = ({})
      var nextAutomaticAttentionRevisions = ({})

      for (var i = 0; i < nextAgents.length; i++) {
        var agent = nextAgents[i]
        if (agentHasPrivateOwner(agent)) continue
        var state = agent.observation ? agent.observation.state : "unknown"
        var attentionRevision = root.attentionRevision(agent)
        nextStates[agent.key] = state
        if (completedAgents[agent.key] && state === "idle") nextCompleted[agent.key] = true
        if ((!federationAvailable || nodeFor(agent.node_id).local) && agentBaselineReady
            && previousAgentStates[agent.key] === "working" && state === "idle")
          nextCompleted[agent.key] = true
        if (state === "working" && attentionRevision > 0 && attentionReason(agent) === "blocked") {
          nextAutomaticAttentionRevisions[agent.key] = attentionRevision
          if (automaticAttentionRevisions[agent.key] !== attentionRevision
              && nodeIsActionable(agent.node_id, "guarded_remote_management"))
            acknowledgeAgent(agent, false, true)
        }
      }

      previousAgentStates = nextStates
      completedAgents = nextCompleted
      automaticAttentionRevisions = nextAutomaticAttentionRevisions
      agentBaselineReady = true
      agents = nextAgents
      syncAgentIndex()
      clampSelection()
  }

  function parseProjects(raw) {
    try {
      var owner = nodeFor(projectActiveNodeId)
      if (!owner || !WorkspaceModel.projectDiscoveryResponseCurrent(
          projectRequestedNodeId, projectActiveNodeId, owner.node_id)) return
      var data = parseEnvelope(raw, "project.list")
      if (typeof data.roots_configured !== "boolean" || !Array.isArray(data.projects)
          || !Array.isArray(data.warnings)) throw new Error("missing project discovery fields")
      var nextProjects = []
      for (var i = 0; i < data.projects.length; i++) {
        var project = data.projects[i]
        if (!project || typeof project.name !== "string" || typeof project.path !== "string"
            || project.path.indexOf("/") !== 0 || typeof project.group !== "string"
            || !Number.isFinite(Number(project.group_order)))
          throw new Error("invalid discovered project")
        nextProjects.push(project)
      }
      projects = nextProjects
      projectRootsConfigured = data.roots_configured
      projectDiscoveryLoaded = true
      projectLoadedNodeId = owner.node_id
      projectDiscoveryExpiresAt = Date.now() + 30000
      projectError = data.warnings.length > 0 ? data.warnings.join(" · ") : ""
      clampProjectSelection()
      openFreshProjectChooser()
    } catch (exception) {
      projects = []
      projectRootsConfigured = false
      projectDiscoveryLoaded = true
      projectLoadedNodeId = ""
      projectDiscoveryExpiresAt = Date.now() + 5000
      projectChooserRequested = false
      projectError = "Could not discover configured projects"
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function selectedAgentHost() {
    for (var i = 0; i < agentHosts.length; i++)
      if (agentHosts[i].name === agentHostName) return agentHosts[i]
    return null
  }

  function selectAgentHost(name) {
    for (var i = 0; i < agentHosts.length; i++) {
      if (agentHosts[i].name === name) {
        agentHostName = agentHosts[i].name
        agentHostCommand = agentHosts[i].command.slice()
        return
      }
    }
  }

  function loadAgentHosts() {
    agentHosts = []
    agentHostName = ""
    agentHostCommand = []
    agentHostError = ""
    if (!integrationStatusSupported) {
      agentHostError = "Upgrade Boomux to discover Agent hosts"
      return
    }
    var node = creationNode
    if (!node) {
      agentHostError = "Select a Node to discover Agent hosts"
      return
    }
    var args = nodeArgs(node.node_id, "remote_integration_management")
    if (args === null) {
      agentHostError = "Agent host discovery is unavailable for this Node"
      return
    }
    agentHostRequestedNodeId = node.node_id
    if (!integrationStatusProcess.running) startAgentHostDiscovery()
  }

  function startAgentHostDiscovery() {
    if (agentHostRequestedNodeId === "") return
    var node = nodeFor(agentHostRequestedNodeId)
    if (!node) return
    var args = nodeArgs(node.node_id, "remote_integration_management")
    if (args === null) return
    agentHostActiveNodeId = node.node_id
    integrationStatusProcess.command = ["boomux", "integration", "status", "--json"].concat(args)
    integrationStatusProcess.running = true
  }

  function parseAgentHosts(raw) {
    if (formMode !== "agent" || agentHostActiveNodeId !== agentHostRequestedNodeId) return
    var hosts = WorkspaceModel.availableAgentHosts(parseEnvelope(raw, "integration.status"))
    agentHosts = hosts
    if (hosts.length === 0) {
      agentHostError = "No available Agent hosts have a current Boomux integration"
      agentHostName = ""
      agentHostCommand = []
      return
    }
    agentHostError = ""
    selectAgentHost(hosts[0].name)
  }

  function loadProjects() {
    if (!projectListSupported) return
    projects = []
    projectRootsConfigured = false
    projectDiscoveryLoaded = false
    projectLoadedNodeId = ""
    projectDiscoveryExpiresAt = 0
    selectedProjectIndex = -1
    projectError = ""
    var node = WorkspaceModel.localWorkspaceCreationNode(nodes)
    if (!node) {
      projectRequestedNodeId = ""
      projectDiscoveryLoaded = true
      projectError = "No eligible local Node is available for project discovery"
      return
    }
    projectRequestedNodeId = WorkspaceModel.projectDiscoveryIdentity(node.node_id)
    if (projectListProcess.running) projectRefreshQueued = true
    else startProjectDiscovery()
  }

  function startProjectDiscovery() {
    if (projectRequestedNodeId === "") return
    var node = nodeFor(projectRequestedNodeId)
    if (!node) return
    projectActiveNodeId = projectRequestedNodeId
    projectListProcess.command = WorkspaceModel.projectDiscoveryCommand(node)
    projectListProcess.running = true
  }

  function ensureLocalProjectDiscovery() {
    if (!opened || !online || !projectListSupported) return
    var node = WorkspaceModel.localWorkspaceCreationNode(nodes)
    if (!node) {
      invalidateProjectDiscovery()
      return
    }
    if (projectListProcess.running) {
      if (projectActiveNodeId !== node.node_id) {
        projectRequestedNodeId = node.node_id
        projectRefreshQueued = true
      }
      return
    }
    if (projectDiscoveryLoaded && projectLoadedNodeId === node.node_id
        && Date.now() < projectDiscoveryExpiresAt) return
    loadProjects()
  }

  function invalidateProjectDiscovery() {
    projects = []
    projectRootsConfigured = false
    projectDiscoveryLoaded = false
    projectLoadedNodeId = ""
    projectDiscoveryExpiresAt = 0
    projectRequestedNodeId = ""
    projectChooserRequested = false
    projectRefreshQueued = false
  }

  function filterProjects() {
    var query = projectQuery.trim().toLowerCase()
    if (query === "") return projects
    return projects.filter(function(project) {
      return String(project.name).toLowerCase().indexOf(query) >= 0
        || String(project.path).toLowerCase().indexOf(query) >= 0
        || String(project.group).toLowerCase().indexOf(query) >= 0
    })
  }

  function clampProjectSelection() {
    if (visibleProjects.length === 0) selectedProjectIndex = -1
    else if (selectedProjectIndex >= visibleProjects.length)
      selectedProjectIndex = visibleProjects.length - 1
  }

  function moveProjectSelection(delta) {
    if (visibleProjects.length === 0) return
    if (selectedProjectIndex < 0)
      selectedProjectIndex = delta < 0 ? visibleProjects.length - 1 : 0
    else
      selectedProjectIndex = Math.max(0, Math.min(selectedProjectIndex + delta, visibleProjects.length - 1))
    projectList.positionViewAtIndex(selectedProjectIndex, ListView.Contain)
  }

  function requestShellNameSuggestion() {
    if (!shellNameSuggestionSupported || !workspaceDetail
        || (formMode !== "shell" && formMode !== "agent")) return
    var owner = creationNode
    if (!owner || !nodeIsActionable(owner.node_id, owner.local
        ? "" : "typed_node_host_services")) return
    var target = workspaceDetail
    if (workspaceDetail.is_global) {
      target = null
      for (var p = 0; p < workspaceDetail.placements.length; p++) {
        if (workspaceDetail.placements[p].node_id === owner.node_id) {
          target = { id: workspaceDetail.placements[p].workspace_id, node_id: owner.node_id }
          break
        }
      }
      if (!target) return
    }
    suggestedNameRequestedIdentity = WorkspaceModel.suggestionIdentity(
      workspaceDetail.key, owner.node_id, target.id)
    if (!shellNameSuggestionProcess.running) startShellNameSuggestion()
  }

  function startShellNameSuggestion() {
    if (!suggestedNameRequestedIdentity) return
    suggestedNameActiveIdentity = suggestedNameRequestedIdentity
    var workspace = null
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === suggestedNameActiveIdentity.workspaceKey) workspace = workspaces[i]
    if (!workspace) return
    shellNameSuggestionProcess.command = ["boomux", "shell", "suggest-name",
      suggestedNameActiveIdentity.ownerWorkspaceId, "--json"]
    var owner = nodeFor(suggestedNameActiveIdentity.nodeId)
    if (owner && !owner.local)
      shellNameSuggestionProcess.command.push("--node", owner.node_id)
    shellNameSuggestionProcess.running = true
  }

  function parseShellNameSuggestion(raw) {
    try {
      var data = parseEnvelope(raw, "shell.suggest-name")
      var owner = suggestedNameActiveIdentity
        ? nodeFor(suggestedNameActiveIdentity.nodeId) : null
      if (!owner || !WorkspaceModel.suggestionResponseMatches(data,
          suggestedNameActiveIdentity, owner.local,
          workspaceDetail && workspaceDetail.is_global)
          || typeof data.name !== "string" || data.name.trim() === "")
        throw new Error("invalid shell name suggestion")
      if ((formMode === "shell" || formMode === "agent") && workspaceDetail
          && suggestedNameRequestedIdentity
          && suggestedNameRequestedIdentity.key === suggestedNameActiveIdentity.key
          && workspaceDetail.key === suggestedNameActiveIdentity.workspaceKey
          && creationNode && creationNode.node_id === suggestedNameActiveIdentity.nodeId
          && !nameFieldEdited
          && nameField.text === "") nameField.text = data.name
    } catch (exception) {
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function inspectWorkspace(workspaceKey) {
    inspectRequestedKey = String(workspaceKey || "")
    if (inspectRequestedKey === "") return
    var workspace = null
    for (var i = 0; i < workspaces.length; i++) if (workspaces[i].key === inspectRequestedKey) workspace = workspaces[i]
    if (!workspace) return
    if (federationAvailable) {
      workspaceDetail = workspace
      openPendingShellIfPresent()
      return
    }
    if (workspaceInspectProcess.running) return
    inspectActiveKey = inspectRequestedKey
    workspaceInspectProcess.command = ["boomux", "workspace", "inspect", workspace.id, "--json"]
    workspaceInspectProcess.running = true
  }

  function parseWorkspaceDetail(raw) {
    try {
      var data = parseEnvelope(raw, "workspace.inspect")
      var workspace = selectedWorkspace
      if (!data.workspace || !workspace || resourceId(data.workspace.id) !== workspace.id) return
      workspaceDetail = WorkspaceModel.normalizeWorkspaceDetail(
        data.workspace, workspace, nodeFor(workspace.node_id))
      openPendingShellIfPresent()
    } catch (exception) {
      workspaceDetail = null
      console.warn("io.github.gardnmi.boomux:", exception)
    }
  }

  function openPendingShellIfPresent() {
    if (!pendingShell || !pendingShell.armed) return
    var models = workspaceDetail && workspaceDetail.key === pendingShell.workspaceKey
      ? [workspaceDetail] : workspaces
    var consumed = WorkspaceModel.consumePendingShell(pendingShell, models)
    pendingShell = consumed.pending
    if (!consumed.resolved) return
    openShell(consumed.resolved.shell)
  }

  function finishRefresh() {
    refreshPending = Math.max(0, refreshPending - 1)
    refreshing = refreshPending > 0
  }

  function workspaceMutationBusy() {
    return workspaceCreateProcess.running || defaultCwdProcess.running
      || daemonStartProcess.running || workspaceCreateRequested !== null
      || pendingWorkspaceCreation !== null || defaultCwdRequest !== null
      || pendingDefaultCwd !== null || actionProcess.running || openProcess.running
  }

  function failWorkspaceCreation(message) {
    workspaceCreateRequested = null
    workspaceCreateStatusQueued = false
    workspaceCreateSnapshotQueued = false
    showActionFailure("Workspace creation unavailable", message)
  }

  function requestGeneratedWorkspace(cwd, name) {
    var path = String(cwd || "")
    if (workspaceMutationBusy()) return
    if (path.indexOf("/") !== 0) {
      showActionFailure("Workspace creation unavailable", "Workspace paths must be absolute")
      return
    }
    if (!atomicWorkspaceCreationSupported) {
      showActionFailure("Workspace creation unavailable",
        "This Boomux CLI does not support atomic Workspace and Shell creation")
      return
    }
    workspaceCreateRequested = { cwd: path, name: String(name || "") }
    actionMessage = "Checking Boomux before creation..."
    requestFreshWorkspaceCreateStatus()
  }

  function requestFreshWorkspaceCreateStatus() {
    if (!workspaceCreateRequested) return
    if (daemonStatusProcess.running) {
      workspaceCreateStatusQueued = true
      return
    }
    workspaceCreateStatusQueued = false
    workspaceCreateStatusActive = true
    daemonStatusProcess.running = true
  }

  function requestFreshWorkspaceCreateSnapshot() {
    if (!workspaceCreateRequested) return
    if (!federationAvailable || !globalWorkspacesAvailable) {
      failWorkspaceCreation(
        "The refreshed Boomux daemon does not support coordinated Node snapshots")
      return
    }
    if (nodeSnapshotProcess.running) {
      workspaceCreateSnapshotQueued = true
      return
    }
    workspaceCreateSnapshotQueued = false
    workspaceCreateSnapshotActive = true
    snapshotActiveEpoch = pollEpoch
    nodeSnapshotProcess.running = true
  }

  function maybeStartWorkspaceCreation() {
    if (!workspaceCreateRequested || workspaceCreateProcess.running) return
    if (!online || !globalWorkspacesAvailable) {
      workspaceCreateRequested = null
      showActionFailure("Workspace creation unavailable",
        "A current coordinated Boomux snapshot is required")
      return
    }
    var node = WorkspaceModel.localWorkspaceCreationNode(nodes)
    if (!node) {
      workspaceCreateRequested = null
      showActionFailure("Workspace creation unavailable",
        "No current eligible local Node is available")
      return
    }
    var request = workspaceCreateRequested
    workspaceCreateRequested = null
    workspaceCreateProcess.command = WorkspaceModel.atomicWorkspaceCreateCommand(
      node.node_id, request.cwd, request.name)
    workspaceCreateProcess.expectedNodeId = node.node_id
    workspaceCreateProcess.running = true
  }

  function resolvePendingWorkspaceCreation() {
    var resolved = WorkspaceModel.resolveAtomicWorkspaceCreation(
      pendingWorkspaceCreation, workspaces)
    if (!resolved) {
      if (WorkspaceModel.atomicWorkspaceCreationConflicts(
          pendingWorkspaceCreation, workspaces)) {
        pendingWorkspaceCreation = null
        pendingWorkspaceConfirmationDeadline = 0
        showActionFailure("Workspace creation failed",
          "The authoritative snapshot did not contain the returned placement and Shell identities")
      }
      return
    }
    pendingWorkspaceCreation = null
    pendingWorkspaceConfirmationDeadline = 0
    selectedWorkspaceKey = resolved.workspace.key
    expandedWorkspaceKey = resolved.workspace.key
    actionMessage = "Workspace created"
  }

  function showProjectChooser() {
    if (workspaceMutationBusy()) return
    if (!online) {
      showActionFailure("Projects unavailable", "Boomux must be online to refresh projects")
      return
    }
    if (!projectListSupported) {
      showActionFailure("Projects unavailable", "This Boomux CLI does not support project discovery")
      return
    }
    projectChooserRequested = true
    loadProjects()
  }

  function openFreshProjectChooser() {
    if (!projectChooserRequested || !online) return
    projectChooserRequested = false
    if (!projectRootsConfigured) {
      showActionFailure("Projects unavailable", "No Boomux project roots are configured")
      return
    }
    panel.enterKeyboardMode()
    formMode = "project"
    projectSearchField.text = ""
    projectQuery = ""
    selectedProjectIndex = -1
    actionMessage = ""
    Qt.callLater(function() { projectSearchField.forceActiveFocus() })
  }

  function workspaceCanChangeDefaultPath(workspace) {
    return workspaceDefaultCwdSupported && daemonProtocolVersion >= 49
      && !workspaceMutationBusy()
      && WorkspaceModel.localActiveWorkspacePlacement(workspace, nodes) !== null
  }

  function requestWorkspaceDefaultPath(workspace) {
    if (!workspaceCanChangeDefaultPath(workspace)) return
    var placement = WorkspaceModel.localActiveWorkspacePlacement(workspace, nodes)
    defaultPathTarget = {
      workspaceKey: workspace.key,
      workspaceId: workspace.id,
      nodeId: placement.node_id,
      ownerWorkspaceId: placement.workspace_id
    }
    formMode = "default-path"
    directoryPickerPurpose = "workspace-default"
    directoryPickerPath = String(placement.default_cwd || home)
    directoryPickerIndex = 0
    directoryPickerOpen = true
    panel.enterKeyboardMode()
    Qt.callLater(function() { directoryPickerKeyHandler.forceActiveFocus() })
  }

  function submitWorkspaceDefaultPath(path) {
    var target = defaultPathTarget
    var workspace = target ? workspaceForKey(target.workspaceKey) : null
    var placement = WorkspaceModel.localActiveWorkspacePlacement(workspace, nodes)
    if (!target || !placement || defaultCwdProcess.running
        || workspace.id !== target.workspaceId || placement.node_id !== target.nodeId
        || placement.workspace_id !== target.ownerWorkspaceId) {
      cancelForm()
      showActionFailure("Shell start folder unavailable",
        "The local Workspace placement changed; reopen its menu")
      return
    }
    defaultCwdRequest = {
      workspaceId: target.workspaceId,
      nodeId: target.nodeId,
      ownerWorkspaceId: target.ownerWorkspaceId,
      defaultCwd: String(path)
    }
    defaultCwdProcess.command = WorkspaceModel.workspaceDefaultCwdCommand(
      target.workspaceId, target.nodeId, path)
    cancelForm()
    actionMessage = "Changing where new Shells start..."
    defaultCwdProcess.running = true
  }

  function resolvePendingDefaultCwd() {
    var resolved = WorkspaceModel.resolveWorkspaceDefaultCwd(pendingDefaultCwd, workspaces)
    if (!resolved) {
      if (WorkspaceModel.workspaceDefaultCwdConflicts(pendingDefaultCwd, workspaces)) {
        pendingDefaultCwd = null
        pendingDefaultCwdConfirmationDeadline = 0
        showActionFailure("Shell start folder change failed",
          "The Workspace no longer reports the selected Shell start folder")
      }
      return
    }
    pendingDefaultCwd = null
    pendingDefaultCwdConfirmationDeadline = 0
    actionMessage = "New Shells will start in the selected folder; existing Shells were not changed"
  }

  function scheduleMutationConfirmation() {
    if (!pendingWorkspaceCreation && !pendingDefaultCwd) {
      mutationConfirmationTimer.stop()
      return
    }
    mutationConfirmationTimer.restart()
  }

  function continueMutationConfirmation() {
    var now = Date.now()
    var warnings = []
    if (pendingWorkspaceCreation && now >= pendingWorkspaceConfirmationDeadline) {
      pendingWorkspaceCreation = null
      pendingWorkspaceConfirmationDeadline = 0
      warnings.push("Workspace creation completed but could not be confirmed; refresh to verify it")
    }
    if (pendingDefaultCwd && now >= pendingDefaultCwdConfirmationDeadline) {
      pendingDefaultCwd = null
      pendingDefaultCwdConfirmationDeadline = 0
      warnings.push("Shell start folder changed but could not be confirmed; refresh to verify it")
    }
    if (warnings.length > 0)
      showActionFailure("Boomux snapshot confirmation incomplete", warnings.join(" · "))
    if (pendingWorkspaceCreation || pendingDefaultCwd) {
      refresh()
      mutationConfirmationTimer.restart()
    }
  }

  function selectTab(tab) {
    if (tab === "workspaces") tab = "agents"
    if (activeTab === tab) return
    activeTab = tab
    focusSection = "lower"
    if (tab === "nodes") syncNodeIndex()
    else syncAgentIndex()
    cancelForm()
  }

  function cycleTab(direction) {
    var tabs = ["agents", "nodes"]
    var index = tabs.indexOf(activeTab)
    var step = direction < 0 ? -1 : 1
    selectTab(tabs[(index + step + tabs.length) % tabs.length])
  }

  function workspaceForKey(workspaceKey) {
    for (var i = 0; i < workspaces.length; i++)
      if (workspaces[i].key === workspaceKey) return workspaces[i]
    return null
  }

  function clampSelection() {
    selectedIndex = Math.max(0, Math.min(selectedIndex, itemCount - 1))
  }

  function clampWorkspaceCursor() {
    selectedWorkspaceIndex = Math.max(0, Math.min(selectedWorkspaceIndex,
      workspaceTreeWorkspaces.length - 1))
    selectedWorkspaceItemIndex = Math.max(0, Math.min(selectedWorkspaceItemIndex,
      cursorWorkspaceItems.length - 1))
  }

  function moveWorkspaceCursor(offset) {
    if (workspaceTreeWorkspaces.length === 0) return
    selectedWorkspaceIndex = Math.max(0, Math.min(selectedWorkspaceIndex + offset,
      workspaceTreeWorkspaces.length - 1))
    selectedWorkspaceItemIndex = 0
    workspaceTreeList.positionViewAtIndex(selectedWorkspaceIndex, ListView.Contain)
  }

  function cycleFocusSection(direction) {
    var sections = ["workspaces"]
    if (cursorWorkspace && cursorWorkspace.key === expandedWorkspaceKey
        && cursorWorkspaceItems.length > 0) sections.push("workspace-items")
    sections.push("lower")
    var index = sections.indexOf(focusSection)
    if (index < 0) index = 0
    focusSection = sections[(index + (direction < 0 ? -1 : 1) + sections.length)
      % sections.length]
    ensureFocusSectionVisible()
  }

  function revealContentItem(item) {
    if (!item || !contentScroll || !contentColumn) return
    var point = item.mapToItem(contentColumn, 0, 0)
    var top = point.y
    var bottom = top + item.height
    if (top < contentScroll.contentY) contentScroll.contentY = Math.max(0, top)
    else if (bottom > contentScroll.contentY + contentScroll.height)
      contentScroll.contentY = Math.max(0, Math.min(
        contentScroll.contentHeight - contentScroll.height, bottom - contentScroll.height))
  }

  function ensureFocusSectionVisible() {
    Qt.callLater(function() {
      if (root.focusSection === "workspaces") root.revealContentItem(workspaceTreeColumn)
      else if (root.focusSection === "lower") root.revealContentItem(
        root.activeTab === "agents" ? agentColumn : nodeColumn)
      else root.revealContentItem(workspaceTreeList)
    })
  }

  function revealWorkspaceTreeCursor() {
    Qt.callLater(function() {
      var workspaceDelegate = workspaceTreeList.itemAtIndex(root.selectedWorkspaceIndex)
      if (workspaceDelegate)
        workspaceDelegate.revealTreeItem(root.selectedWorkspaceItemIndex)
    })
  }

  function revealSettingsItem(item) {
    if (!item || !settingsScroll || !settingsColumn || !item.activeFocus) return
    var point = item.mapToItem(settingsColumn, 0, 0)
    if (point.y < settingsScroll.contentY) settingsScroll.contentY = Math.max(0, point.y)
    else if (point.y + item.height > settingsScroll.contentY + settingsScroll.height)
      settingsScroll.contentY = Math.max(0,
        point.y + item.height - settingsScroll.height)
  }

  function movePanelCursor(dx, dy) {
    if (actionMenuTarget) {
      moveActionMenu(dy !== 0 ? dy : dx)
      return
    }
    if (focusSection === "workspaces") {
      if (dy !== 0) moveWorkspaceCursor(dy)
      else if (dx > 0 && cursorWorkspace && cursorWorkspace.key !== expandedWorkspaceKey)
        toggleWorkspaceExpansion(cursorWorkspace)
      else if (dx < 0 && cursorWorkspace && cursorWorkspace.key === expandedWorkspaceKey)
        toggleWorkspaceExpansion(cursorWorkspace)
      return
    }
    if (focusSection === "workspace-items") {
      if (dy !== 0 && cursorWorkspaceItems.length > 0) {
        selectedWorkspaceItemIndex = Math.max(0, Math.min(selectedWorkspaceItemIndex + dy,
          cursorWorkspaceItems.length - 1))
        revealWorkspaceTreeCursor()
      } else if (dx < 0) focusSection = "workspaces"
      return
    }
    if (dy !== 0) moveSelection(dy)
    else if (dx < 0) focusSection = "workspaces"
  }

  function activatePanelCursor() {
    if (actionMenuTarget) {
      if (currentActionMenuAction !== "") runActionMenuAction(currentActionMenuAction)
      return
    }
    if (focusSection === "workspaces") activateWorkspaceRow(cursorWorkspace)
    else if (focusSection === "workspace-items") openWorkspaceTreeItem(cursorWorkspaceItem)
    else activateSelected()
  }

  function showCursorActionMenu() {
    var target = null
    if (focusSection === "workspaces" && cursorWorkspace)
      target = { kind: "workspace", workspace: cursorWorkspace }
    else if (focusSection === "workspace-items") target = cursorWorkspaceItem
    else if (activeTab === "nodes" && selectedItem)
      target = { kind: "node", node: selectedItem }
    if (target) showActionMenuAt(target, keyCatcher.width - Style.space(172),
      Style.space(72))
  }

  function moveSelection(offset) {
    if (editing || itemCount === 0) return
    selectedIndex = Math.max(0, Math.min(selectedIndex + offset, itemCount - 1))
    if (activeTab === "agents") {
      selectedAgentKey = paneAgents[selectedIndex].key
      agentList.positionViewAtIndex(selectedIndex, ListView.Contain)
    } else {
      selectedNodeId = visibleNodes[selectedIndex].node_id
      nodeList.positionViewAtIndex(selectedIndex, ListView.Contain)
    }
  }

  function activateSelected() {
    if (activeTab === "agents") openAgent(selectedItem)
    else if (activeTab === "nodes" && selectedItem) showCursorActionMenu()
  }

  function openWorkspacePanel(workspace) {
    if (!workspace) return
    selectedWorkspaceKey = workspace.key
    workspaceDetail = workspace
    expandedWorkspaceKey = workspace.key
    open()
  }

  function toggleWorkspaceExpansion(workspace) {
    if (!workspace) return
    var expanding = expandedWorkspaceKey !== workspace.key
    expandedWorkspaceKey = expanding ? workspace.key : ""
    if (expanding) {
      var itemCount = WorkspaceModel.workspaceTreeItems(workspace).length
      setWorkspaceTreeHeight(Math.max(workspaceTreeHeight,
        Style.space(62 + Math.min(itemCount, 5) * 40)))
      positionWorkspace(workspace.key)
    }
  }

  function activateWorkspaceRow(workspace) {
    if (!workspaceCanOpen(workspace)) return
    var presentationOnly = workspace.is_global
      && cliFeatures.indexOf("desktop_workspace_show") >= 0
    selectedWorkspaceKey = workspace.key
    workspaceDetail = workspace
    expandedWorkspaceKey = workspace.key
    if (!presentationOnly) requestWorkspaceSelection(workspace)
    var screen = currentNoticeScreen()
    if (actionProcess.running) {
      pendingWorkspaceOpen = { key: workspace.key, noticeScreen: screen,
        presentationOnly: presentationOnly }
      actionMessage = "Opening " + String(workspace.name) + " next..."
      return
    }
    openWorkspace(workspace, screen, presentationOnly)
  }

  function showWorkspaceForm(workspace, mode) {
    if (!workspace) return
    selectedWorkspaceKey = workspace.key
    workspaceDetail = workspace
    expandedWorkspaceKey = workspace.key
    showForm(mode)
  }

  function startPendingWorkspaceOpen() {
    if (!pendingWorkspaceOpen || actionProcess.running) return
    var request = pendingWorkspaceOpen
    pendingWorkspaceOpen = null
    var workspace = workspaceForKey(request.key)
    if (workspace) openWorkspace(workspace, request.noticeScreen, request.presentationOnly)
  }

  function openWorkspaceTreeItem(item) {
    if (!item) return
    if (item.kind === "launcher") openWorkspaceItem(item)
    else openShell(item.shell)
  }

  function positionActiveWorkspace() {
    if (activeBoomuxWorkspaceId === "") return
    for (var i = 0; i < visibleWorkspaces.length; i++) {
      if (visibleWorkspaces[i].is_global
          && visibleWorkspaces[i].id === activeBoomuxWorkspaceId) {
        positionWorkspace(visibleWorkspaces[i].key)
        return
      }
    }
  }

  function positionWorkspace(workspaceKey) {
    if (!workspaceTreeList || !workspaceKey) return
    pendingWorkspacePositionKey = workspaceKey
    applyWorkspacePosition(workspaceKey)
    workspacePositionTimer.restart()
  }

  function applyWorkspacePosition(workspaceKey) {
    for (var i = 0; i < visibleWorkspaces.length; i++) {
      if (visibleWorkspaces[i].key !== workspaceKey) continue
      var index = i
      Qt.callLater(function() {
        workspaceTreeList.positionViewAtIndex(index, ListView.Beginning)
      })
      return
    }
  }

  function setWorkspaceTreeHeight(height) {
    var minimum = Style.space(150)
    var maximum = Math.max(minimum, panel.height - Style.space(260))
    workspaceTreeHeight = Math.round(Math.max(minimum, Math.min(Number(height), maximum)))
  }

  function requestWorkspaceSelection(workspace) {
    if (!workspaceSelectionSupported) {
      showActionFailure("Workspace selection unavailable",
        "Boomux 0.27.0 or newer is required for a default Workspace")
      return
    }
    var request = workspace && workspace.is_global && !workspace.closing
      ? { id: String(workspace.id), name: String(workspace.name) }
      : { id: "", name: "" }
    workspaceSelectionRequested = request
    startWorkspaceSelection()
  }

  function startWorkspaceSelection() {
    if (!workspaceSelectionRequested || workspaceSelectionProcess.running) return
    if (workspaceSelectionRequested.id === workspaceSelectionAppliedId) {
      return
    }
    workspaceSelectionActive = workspaceSelectionRequested
    workspaceSelectionProcess.command = workspaceSelectionActive.id === ""
      ? ["boomux", "workspace", "clear"]
      : ["boomux", "workspace", "select", workspaceSelectionActive.id]
    workspaceSelectionProcess.running = true
  }

  function syncWorkspaceIndex() {
    if (activeTab !== "workspaces") return
    for (var i = 0; i < visibleWorkspaces.length; i++) {
      if (visibleWorkspaces[i].key === selectedWorkspaceKey) {
        selectedIndex = i
        return
      }
    }
    clampSelection()
  }

  function syncNodeIndex() {
    if (activeTab !== "nodes") return
    for (var i = 0; i < visibleNodes.length; i++) {
      if (visibleNodes[i].node_id === selectedNodeId) {
        selectedIndex = i
        return
      }
    }
    selectedIndex = visibleNodes.length > 0 ? 0 : -1
    selectedNodeId = visibleNodes.length > 0 ? visibleNodes[0].node_id : ""
  }

  function syncAgentIndex() {
    if (activeTab !== "agents") return
    for (var i = 0; i < paneAgents.length; i++) {
      if (paneAgents[i].key === selectedAgentKey) {
        selectedIndex = i
        return
      }
    }
    selectedIndex = paneAgents.length > 0 ? 0 : -1
    selectedAgentKey = paneAgents.length > 0 ? paneAgents[0].key : ""
  }

  function compactPath(path) {
    var value = String(path || "")
    if (home !== "" && value === home) return "~"
    return home !== "" && value.indexOf(home + "/") === 0 ? "~" + value.substring(home.length) : value
  }

  function workspaceCanOpen(workspace) {
    if (!workspace || workspace.closing) return false
    if (workspace.is_global) return true
    if (workspace.is_external && !workspace.available) return false
    return nodeIsActionable(workspace.node_id, "guarded_remote_management")
  }

  function workspaceCreationReason(workspace) {
    return WorkspaceModel.workspaceCreationBlockReason(
      workspace, eligibleCreationNodes.length)
  }

  function openWorkspace(workspace, noticeScreen, presentationOnly) {
    if (!workspaceCanOpen(workspace) || actionProcess.running) return
    panel.exitKeyboardMode()
    var availablePlacements = workspace.is_global ? workspace.placements.filter(function(placement) {
      return placement.available
    }).length : 1
    var unavailablePlacements = workspace.is_global
      ? Math.max(0, workspace.placements.length - availablePlacements) : 0
    pendingAction = { kind: presentationOnly ? "show-workspace" : "open-workspace",
      key: workspace.key, id: workspace.id,
      nodeId: workspace.node_id || "", name: String(workspace.name),
      noticeScreen: noticeScreen || null, availablePlacements: availablePlacements,
      unavailablePlacements: unavailablePlacements }
    actionMessage = (presentationOnly ? "Showing " : "Opening ")
      + String(workspace.name) + "..."
    actionProcess.command = WorkspaceModel.workspaceOpenCommand(workspace,
      cliFeatures.indexOf("workspace_open_desktop_show") >= 0, presentationOnly)
    actionProcess.running = true
  }

  function openShell(shell, agent) {
    if (!shell || !shell.id || openProcess.running
        || !resourceIsActionable(shell, "remote_pty_attachment")) return
    panel.exitKeyboardMode()
    pendingOpenAgent = agent || null
    pendingOpenKey = resourceKey(shell.node_id, shell.id)
    pendingOpenRunKey = resourceKey(shell.node_id,
      shell.run ? shell.run.id : shell.run_id)
    actionMessage = "Opening terminal..."
    var owner = nodeFor(shell.node_id)
    var workspace = workspaceForKey(shell.workspace_key)
    if (cliFeatures.indexOf("coordinated_shell_desktop_placement") < 0)
      workspace = null
    openProcess.command = WorkspaceModel.shellOpenCommand(
      shell, workspace, owner && owner.local)
    openProcess.running = true
  }

  function openAgent(agent) {
    if (!agent) return
    var shell = WorkspaceModel.retainedShellForAgent(agent, shells)
    if (!shell) {
      if (attentionRevision(agent) > 0 && !agentCanAcknowledge(agent)) {
        showActionFailure("Agent unavailable",
          "Remote attention remains visible; this CLI cannot acknowledge it")
      } else {
        showActionFailure("Agent unavailable",
          "This Agent's shell was removed; use Dismiss to acknowledge its notification")
      }
      return
    }
    var target = WorkspaceModel.agentOpenTarget(agent, shells,
      nodeIsActionable(agent.node_id, "remote_pty_attachment"))
    if (!target) {
      showActionFailure("Agent unavailable", "This Agent placement is unavailable")
      return
    }
    openShell(target, agent)
  }

  function agentShellRetained(agent) {
    return WorkspaceModel.retainedShellForAgent(agent, shells) !== null
  }

  function agentIsCurrent(agent) {
    if (!agent || !agent.shell_id || !agent.run_id) return false
    for (var i = 0; i < shells.length; i++) {
      var shell = shells[i]
      if (shell.node_id === agent.node_id && shell.id === agent.shell_id
          && shell.run && resourceId(shell.run.id) === agent.run_id)
        return true
    }
    return false
  }

  function agentHasPrivateOwner(agent) {
    return WorkspaceModel.agentHasPrivateOwner(agent, shells)
  }

  function agentIsProjectedCurrent(agent) {
    if (!agentIsCurrent(agent)) return false
    var observedAt = agent.observation ? Number(agent.observation.observed_at_ms || 0) : 0
    var startedAt = Number(agent.started_at_ms || 0)
    for (var i = 0; i < agents.length; i++) {
      var candidate = agents[i]
      var state = candidate.observation ? candidate.observation.state : "unknown"
      if (candidate.key === agent.key || candidate.node_id !== agent.node_id
          || candidate.shell_id !== agent.shell_id
          || candidate.run_id !== agent.run_id || state === "inactive" || state === "done") continue
      var candidateObservedAt = candidate.observation
        ? Number(candidate.observation.observed_at_ms || 0) : 0
      var candidateStartedAt = Number(candidate.started_at_ms || 0)
      if (candidateObservedAt > observedAt
          || (candidateObservedAt === observedAt && candidateStartedAt > startedAt)
          || (candidateObservedAt === observedAt && candidateStartedAt === startedAt
            && String(candidate.id) > String(agent.id))) return false
    }
    return true
  }

  function openWorkspaceItem(item) {
    if (!item) return
    if (item.kind === "launcher") {
      if (actionProcess.running || !resourceIsActionable(item,
          "remote_launcher_invocation")) return
      panel.exitKeyboardMode()
      pendingAction = { kind: "invoke-launcher", key: item.key, nodeId: item.node_id }
      actionMessage = "Launching " + String(item.name) + "..."
      var owner = nodeFor(item.node_id)
      actionProcess.command = WorkspaceModel.qualifiedCommand(
        ["boomux", "launcher", "invoke"], item.id, item.node_id, owner && owner.local)
      actionProcess.running = true
      return
    }
    openShell(item.shell, item.agent)
  }

  function showActionMenu(target, source) {
    if (!target || !source) return
    var point = source.mapToItem(keyCatcher, 0, source.height)
    showActionMenuAt(target, point.x, point.y)
  }

  function showActionMenuAt(target, x, y) {
    if (!target || actionMenuActionsFor(target).length === 0) return
    actionMenuX = Math.max(Style.space(8), Math.min(x,
      keyCatcher.width - Style.space(172)))
    actionMenuAnchorY = y
    actionMenuY = Math.max(Style.space(8), y)
    actionMenuIndex = 0
    actionMenuTarget = target
    Qt.callLater(function() {
      if (!root.actionMenuTarget) return
      root.actionMenuY = Math.max(Style.space(8), Math.min(root.actionMenuAnchorY,
        keyCatcher.height - actionMenuCard.height - Style.space(8)))
    })
  }

  function actionMenuActionsFor(target) {
    if (!target) return []
    var actions = []
    if (target.kind === "workspace") {
      if (workspaceMutationBusy()) return actions
      if (workspaceCreationReason(target.workspace) === "" && !actionProcess.running
          && !openProcess.running) actions.push("shell")
      if (workspaceCanChangeDefaultPath(target.workspace)) actions.push("default-path")
      if (workspaceCanRename(target.workspace)) actions.push("rename")
      if (workspaceCanRemove(target.workspace)) actions.push("remove")
      return actions
    }
    if (target.kind === "node") {
      var nodeBusy = nodeShellProcess.running || nodeUpgradeProcess.running
        || nodeUninstallProcess.running || nodeReauthenticateProcess.running
        || actionProcess.running
      if (nodeCanReauthenticate(target.node) && !nodeBusy) actions.push("authenticate")
      else if (target.node.workspace_owner_eligible
          && nodeIsActionable(target.node.node_id) && activeBoomuxWorkspaceId !== ""
          && !nodeBusy)
        actions.push("shell")
      if (nodeCanUpgrade(target.node) && !nodeBusy) actions.push("update")
      if (nodeCanUninstall(target.node) && !nodeBusy) actions.push("uninstall")
      if (!actionProcess.running && !nodeShellProcess.running
          && !nodeUpgradeProcess.running && !nodeUninstallProcess.running
          && !nodeReauthenticateProcess.running)
        actions.push("remove")
      return actions
    }
    if (itemCanRename(target)) return ["rename", "remove"]
    return []
  }

  function moveActionMenu(offset) {
    if (currentActionMenuActions.length === 0 || offset === 0) return
    actionMenuIndex = (actionMenuIndex + (offset < 0 ? -1 : 1)
      + currentActionMenuActions.length) % currentActionMenuActions.length
  }

  function closeActionMenu() {
    actionMenuTarget = null
    actionMenuIndex = 0
  }

  function workspaceCanRename(workspace) {
    return workspaceCanRemove(workspace)
  }

  function itemCanRename(item) {
    var node = item ? nodeFor(item.node_id) : null
    return !!item && !!node && node.local && !workspaceMutationBusy()
  }

  function requestRename(target) {
    if (!target) return
    closeActionMenu()
    var allowed = target.kind === "workspace"
      ? workspaceCanRename(target.workspace) : itemCanRename(target)
    if (!allowed) return
    panel.enterKeyboardMode()
    renameError = ""
    renameTarget = target
  }

  function cancelRename() {
    renameTarget = null
    renameError = ""
  }

  function confirmRename() {
    var target = renameTarget
    var name = renameField.text.trim()
    if (!target || actionProcess.running) return
    if (name === "") {
      renameError = "Name is required"
      return
    }
    var currentName = target.kind === "workspace"
      ? String(target.workspace.name) : String(target.name)
    if (name === currentName) {
      cancelRename()
      return
    }
    if (target.kind === "workspace") {
      if (!workspaceCanRename(target.workspace)) return
      pendingAction = { kind: "rename-workspace", key: target.workspace.key }
      actionProcess.command = ["boomux", "workspace", "rename",
        String(target.workspace.id), name]
    } else {
      if (!itemCanRename(target)) return
      var owningWorkspace = target.workspace || workspaceDetail
      if (!owningWorkspace) return
      pendingAction = { kind: target.kind === "launcher"
        ? "rename-launcher" : "rename-shell", key: target.key, nodeId: target.node_id }
      actionProcess.command = target.kind === "launcher"
        ? ["boomux", "launcher", "rename", String(target.id), name, "--workspace",
          String(target.launcher.owner_workspace_id || owningWorkspace.id)]
        : ["boomux", "shell", "rename", String(target.shell.id), name, "--workspace",
          String(target.shell.owner_workspace_id || owningWorkspace.id)]
    }
    actionMessage = "Renaming " + currentName + "..."
    renameTarget = null
    renameError = ""
    actionProcess.running = true
  }

  function runActionMenuAction(action) {
    var target = actionMenuTarget
    closeActionMenu()
    if (!target) return
    if (target.kind === "workspace") {
      var workspace = target.workspace
      if (action === "shell") showWorkspaceForm(workspace, "shell")
      else if (action === "default-path") requestWorkspaceDefaultPath(workspace)
      else if (action === "rename") requestRename(target)
      else if (action === "remove") requestRemoveWorkspace(workspace)
      return
    }
    if (target.kind === "node") {
      if (action === "shell") createShellOnNode(target.node)
      else if (action === "authenticate") reauthenticateNode(target.node)
      else if (action === "update") updateNode(target.node)
      else if (action === "uninstall") requestUninstallNode(target.node)
      else if (action === "remove") requestForgetNode(target.node)
      return
    }
    if (action === "rename") requestRename(target)
    else if (action === "remove") requestRemoveItem(target)
  }

  function requestRemoveItem(item) {
    var node = item ? nodeFor(item.node_id) : null
    if (!item || !node || !node.local
        || actionProcess.running || openProcess.running) return
    panel.enterKeyboardMode()
    removeItemDialog.selectedIndex = 0
    itemToRemove = item
  }

  function workspaceCanRemove(workspace) {
    if (!workspace || workspaceMutationBusy()) return false
    if (workspace.is_global) return true
    var node = nodeFor(workspace.node_id)
    return !globalWorkspacesAvailable && !!node && node.local
  }

  function requestRemoveWorkspace(workspace) {
    if (!workspaceCanRemove(workspace)) return
    panel.enterKeyboardMode()
    removeItemDialog.selectedIndex = 0
    itemToRemove = { kind: "workspace", workspace: workspace }
  }

  function requestForgetNode(node) {
    if (!node || node.local || actionProcess.running || nodeShellProcess.running
        || nodeUpgradeProcess.running || nodeUninstallProcess.running
        || nodeReauthenticateProcess.running) return
    panel.enterKeyboardMode()
    removeItemDialog.selectedIndex = 0
    itemToRemove = { kind: "node", node: node }
  }

  function requestUninstallNode(node) {
    if (!nodeCanUninstall(node) || actionProcess.running || nodeShellProcess.running
        || nodeUpgradeProcess.running || nodeUninstallProcess.running
        || nodeReauthenticateProcess.running) return
    panel.enterKeyboardMode()
    removeItemDialog.selectedIndex = 0
    itemToRemove = { kind: "node-uninstall", node: node }
  }

  function cancelRemoveItem() {
    itemToRemove = null
  }

  function removeItemMessage(item) {
    if (!item) return ""
    if (item.kind === "workspace")
      return "Remove Workspace " + String(item.workspace.name)
        + "? This terminates its running Shells and removes its launchers, retained terminal state, Agent records, attention, and Workspace metadata."
    if (item.kind === "node-uninstall")
      return "Uninstall Boomux from remote Node " + String(item.node.alias)
        + "? This stops every Boomux-managed process on that Node, removes its current Boomux integrations and executable, preserves durable state and configuration, then forgets the local registration. Boomux will show the exact impact and require confirmation in a terminal."
    if (item.kind === "node")
      return "Forget remote Node " + String(item.node.alias)
        + "? This removes only the local registration and cached projection. It does not contact the Node or stop its processes."
    if (item.kind === "launcher")
      return "Remove launcher " + String(item.name)
        + "? This deletes its workspace definition. Applications it already launched keep running."
    return "Close Shell " + String(item.name)
      + "? This terminates it if running and deletes its shell definition and retained terminal state. Durable Agent history may remain."
  }

  function removeConfirmText(item) {
    if (!item) return "Remove"
    if (item.kind === "node-uninstall") return "Uninstall"
    if (item.kind === "node") return "Just Forget"
    if (item.kind === "shell" || item.kind === "command" || item.kind === "agent")
      return "Close"
    return "Remove"
  }

  function confirmRemoveItem() {
    var item = itemToRemove
    itemToRemove = null
    if (item && item.kind === "workspace") {
      if (!workspaceCanRemove(item.workspace)) return
      pendingAction = { kind: "remove-workspace", key: item.workspace.key }
      actionMessage = "Removing " + String(item.workspace.name) + "..."
      actionProcess.command = WorkspaceModel.workspaceCloseCommand(item.workspace)
      actionProcess.running = true
      return
    }
    if (item && item.kind === "node") {
      if (item.node.local || actionProcess.running || nodeShellProcess.running
          || nodeUpgradeProcess.running || nodeUninstallProcess.running
          || nodeReauthenticateProcess.running) return
      pendingAction = { kind: "forget-node", key: item.node.node_id }
      actionMessage = "Forgetting " + String(item.node.alias) + "..."
      actionProcess.command = ["boomux", "node", "forget",
        String(item.node.node_id), "--json"]
      actionProcess.running = true
      return
    }
    if (item && item.kind === "node-uninstall") {
      if (!nodeCanUninstall(item.node) || actionProcess.running || nodeShellProcess.running
          || nodeUpgradeProcess.running || nodeUninstallProcess.running
          || nodeReauthenticateProcess.running) return
      actionMessage = "Opening guided uninstall for " + String(item.node.alias) + "..."
      nodeUninstallAlias = String(item.node.alias)
      nodeUninstallProcess.command = WorkspaceModel.guidedNodeUninstallCommand(item.node.node_id)
      nodeUninstallProcess.running = true
      return
    }
    if (!item || actionProcess.running) return
    var owningWorkspace = item.workspace || workspaceDetail
    if (!owningWorkspace) return
    pendingAction = { kind: item.kind === "launcher" ? "remove-launcher" : "remove-shell",
      key: item.key, nodeId: item.node_id }
    actionMessage = (item.kind === "launcher" ? "Removing " : "Closing ")
      + String(item.name) + "..."
    actionProcess.command = item.kind === "launcher"
      ? ["boomux", "launcher", "remove", String(item.id), "--workspace",
        String(item.launcher.owner_workspace_id || owningWorkspace.id)]
      : ["boomux", "shell", "close", String(item.shell.id), "--workspace",
        String(item.shell.owner_workspace_id || owningWorkspace.id)]
    actionProcess.running = true
  }

  function persistPaneSettings(values) {
    var next = ({})
    for (var key in settings) if (key !== "id") next[key] = settings[key]
    for (var changed in values) next[changed] = values[changed]
    settings = next
    if (bar && bar.shell) bar.shell.updateEntryInline(moduleName, next)
  }

  function showSettings() {
    panel.enterKeyboardMode()
    cancelForm()
    itemToRemove = null
    settingsOpen = true
    Qt.callLater(function() { settingsBackButton.forceActiveFocus() })
  }

  function hideSettings() {
    settingsOpen = false
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openBoomuxConfig() {
    if (!bar || !cliAvailable) return
    bar.run("omarchy-launch-tui --app-id=TUI.float boomux config edit")
    close()
  }

  function applyWebStatus(raw, command) {
    var status = WorkspaceModel.normalizeWebStatus(parseEnvelope(raw, command))
    webRunning = status.running
    webTailscale = status.tailscale
    webDashboardUrl = status.dashboard_url
    webOpencodeUrl = status.opencode_url
  }

  function startWeb() {
    if (!webLifecycleSupported || !online || webStartProcess.running
        || webStopProcess.running) return
    actionMessage = "Publishing Boomux Web through Tailscale..."
    webStartProcess.running = true
  }

  function stopWeb() {
    if (!webLifecycleSupported || !webRunning || webStartProcess.running
        || webStopProcess.running) return
    actionMessage = "Stopping Boomux Web..."
    webStopProcess.running = true
  }

  function openWeb() {
    if (webRunning && webDashboardUrl !== "") Qt.openUrlExternally(webDashboardUrl)
  }

  function createNode() {
    if (!bar || !federationAvailable) return
    bar.run("omarchy-launch-tui --app-id=TUI.float boomux __guided-node-add")
  }

  function createShellOnNode(node) {
    if (!node || node.local || nodeShellProcess.running || nodeUpgradeProcess.running
        || nodeUninstallProcess.running || nodeReauthenticateProcess.running
        || !nodeIsActionable(node.node_id)) return
    if (activeBoomuxWorkspaceId === "") {
      showNotice("Shell creation unavailable",
        "Show the Boomux Workspace where the Shell should be created",
        currentNoticeScreen(), true)
      return
    }
    nodeShellAlias = String(node.alias)
    actionMessage = "Creating Shell on " + nodeShellAlias + "..."
    nodeShellProcess.command = ["boomux", "shell", "create",
      String(activeBoomuxWorkspaceId), "--node", String(node.node_id), "--open"]
    nodeShellProcess.running = true
  }

  function updateNode(node) {
    if (!nodeCanUpgrade(node) || nodeUpgradeProcess.running || nodeShellProcess.running
        || nodeUninstallProcess.running || nodeReauthenticateProcess.running
        || actionProcess.running) return
    nodeUpgradeAlias = String(node.alias)
    nodeUpgradeProcess.command = WorkspaceModel.guidedNodeUpgradeCommand(node.node_id)
    nodeUpgradeProcess.running = true
  }

  function reauthenticateNode(node) {
    if (!nodeCanReauthenticate(node) || nodeReauthenticateProcess.running
        || nodeUpgradeProcess.running || nodeUninstallProcess.running
        || nodeShellProcess.running || actionProcess.running) return
    nodeReauthenticateAlias = String(node.alias)
    nodeReauthenticateProcess.command
      = WorkspaceModel.guidedNodeReauthenticateCommand(node.node_id)
    nodeReauthenticateProcess.running = true
    close()
  }

  function formatTimestamp(timestamp) {
    var value = Number(timestamp || 0)
    return value > 0 ? Qt.formatDateTime(new Date(value), "MMM d, HH:mm") : "unknown"
  }

  function workspaceActiveAgentCount(workspace) {
    return visibleAgents.filter(function(agent) {
      return agent.workspace_key === workspace.key
    }).length
  }

  function workspaceHealthSummary(workspace) {
    if (!workspace) return ""
    if (!workspace.is_global) return (workspace.is_external && !workspace.available
      ? "unavailable · " : "")
      + String(workspace.node_health || "online").split("_").join(" ")
    if (workspace.closing) return "closing · " + workspace.placements.filter(function(placement) {
      return placement.state === "close_pending"
    }).length + " pending"
    var unavailable = workspace.placements.filter(function(placement) {
      return !placement.available
    }).length
    return unavailable > 0 ? unavailable + " unavailable" : "all placements available"
  }

  function agentDisplayName(agent) {
    if (!agent) return "Agent"
    for (var i = 0; i < shells.length; i++)
      if (shells[i].node_id === agent.node_id && shells[i].id === agent.shell_id) return shells[i].name
    return agent.name
  }

  function attentionRevision(agent) {
    return agent && agent.attention && agent.attention.observation
      ? Number(agent.attention.observation.revision) : 0
  }

  function attentionReason(agent) {
    return agent && agent.attention && agent.attention.reason ? String(agent.attention.reason) : ""
  }

  function agentNeedsAttention(agent) {
    return attentionRevision(agent) > 0 && attentionReason(agent) === "blocked"
  }

  function agentCanAcknowledge(agent) {
    var node = agent ? nodeFor(agent.node_id) : null
    return !!node && node.local && nodeIsActionable(agent.node_id, "")
  }

  function acknowledgeAgent(agent, dismissed, automatic) {
    var revision = attentionRevision(agent)
    if (revision <= 0 || !agentCanAcknowledge(agent)) return
    var queue = acknowledgeQueue.slice()
    for (var i = 0; i < queue.length; i++) {
      if (queue[i].agentKey !== agent.key || queue[i].revision !== revision) continue
      if (dismissed) {
        queue[i].dismissed = true
        queue[i].automatic = false
        acknowledgeQueue = queue
      }
      return
    }
    queue.push(Object.assign(WorkspaceModel.acknowledgementIdentity(agent, revision), {
      dismissed: !!dismissed,
      automatic: !!automatic
    }))
    acknowledgeQueue = queue
    startNextAcknowledgement()
  }

  function dismissAgent(agent) {
    if (!agent || (!completedAgents[agent.key] && attentionRevision(agent) <= 0)
        || !agentCanAcknowledge(agent)) return
    clearCompletedAgent(agent.key)
    if (attentionRevision(agent) > 0) {
      actionMessage = "Dismissing Agent notification..."
      acknowledgeAgent(agent, true)
    } else {
      actionMessage = "Agent notification dismissed"
    }
  }

  function startNextAcknowledgement() {
    if (acknowledgeProcess.running || acknowledgeQueue.length === 0) return
    activeAcknowledgement = acknowledgeQueue[0]
    acknowledgeProcess.command = ["boomux", "attention", "acknowledge",
      activeAcknowledgement.agentId, "--observation-revision",
      String(activeAcknowledgement.revision), "--json"]
    acknowledgeProcess.running = true
  }

  function countCompletedAgents() {
    var completed = ({})
    for (var i = 0; i < agents.length; i++) {
      if (agentHasPrivateOwner(agents[i])) continue
      if (completedAgents[agents[i].key] && agentIsProjectedCurrent(agents[i]))
        completed[agents[i].key] = true
      if (attentionReason(agents[i]) === "completed" && attentionRevision(agents[i]) > 0)
        completed[agents[i].key] = true
    }
    return Object.keys(completed).length
  }

  function clearCompletedAgent(agentKey) {
    if (!completedAgents[agentKey]) return
    var nextCompleted = ({})
    for (var id in completedAgents)
      if (id !== agentKey) nextCompleted[id] = completedAgents[id]
    completedAgents = nextCompleted
  }

  function showForm(mode, preferredNodeId) {
    if (mode !== "shell" && mode !== "agent") return
    var blocked = WorkspaceModel.workspaceCreationBlockReason(
      workspaceDetail, eligibleCreationNodes.length)
    if (blocked !== "") {
      showActionFailure("Creation unavailable", blocked)
      return
    }
    if (globalWorkspacesAvailable && workspaceDetail && workspaceDetail.is_global) {
      var preferredNode = nodeFor(preferredNodeId)
      creationNodeId = preferredNode && preferredNode.workspace_owner_eligible
        ? preferredNode.node_id : WorkspaceModel.defaultCreationNodeId(nodes)
      if (eligibleCreationNodes.length === 0) {
        showActionFailure("Creation unavailable",
          "No Node is currently eligible for Workspace placement")
        return
      }
    } else if (workspaceDetail) {
      creationNodeId = workspaceDetail.node_id
      var externalOwner = nodeFor(creationNodeId)
      if (!externalOwner || !externalOwner.local) {
        showActionFailure("Creation unavailable",
          "Creation is unavailable for this owner Workspace")
        return
      }
    }
    panel.enterKeyboardMode()
    formMode = mode
    actionMessage = ""
    nameFieldEdited = false
    nameField.text = ""
    applyCreationNodeDefaults()
    requestShellNameSuggestion()
    if (mode === "agent") loadAgentHosts()
    Qt.callLater(function() {
      nameField.forceActiveFocus()
    })
  }

  function placementForNode(workspace, nodeId) {
    if (!workspace || !workspace.placements) return null
    for (var i = 0; i < workspace.placements.length; i++)
      if (workspace.placements[i].node_id === nodeId) return workspace.placements[i]
    return null
  }

  function applyCreationNodeDefaults() {
    var placement = workspaceDetail && workspaceDetail.is_global
      ? placementForNode(workspaceDetail, creationNodeId) : workspaceDetail
    var cwd = placement && placement.default_cwd
      ? String(placement.default_cwd) : ""
    cwdIsExact = cwd !== ""
    cwdField.text = cwd
  }

  function selectCreationNode(nodeId) {
    var node = nodeFor(nodeId)
    if (!node || !node.workspace_owner_eligible) return
    creationNodeId = node.node_id
    nameField.text = ""
    nameFieldEdited = false
    applyCreationNodeDefaults()
    requestShellNameSuggestion()
    if (formMode === "agent") loadAgentHosts()
  }

  function formCanSubmit() {
    if (formMode === "project") return online && selectedProject !== null
      && projectRootsConfigured && projectDiscoveryLoaded && !workspaceMutationBusy()
    if (nameField.text.trim() === "") return false
    if (formMode === "agent" && agentHostCommand.length === 0) return false
    if (workspaceCreationReason(workspaceDetail) !== "") return false
    if (!globalWorkspacesAvailable) return true
    return creationNode !== null
  }

  function cancelForm() {
    directoryPickerOpen = false
    directoryPickerPurpose = "resource"
    defaultPathTarget = null
    projectRequestedNodeId = ""
    agentHostRequestedNodeId = ""
    agentHosts = []
    agentHostName = ""
    agentHostCommand = []
    agentHostError = ""
    suggestedNameRequestedIdentity = null
    formMode = ""
    if (opened) Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function openDirectoryPicker() {
    var cwd = cwdIsExact ? cwdField.text : cwdField.text.trim()
    directoryPickerPath = cwd.indexOf("/") === 0 ? cwd : home
    directoryPickerIndex = 0
    directoryPickerOpen = true
    Qt.callLater(function() { directoryPickerKeyHandler.forceActiveFocus() })
  }

  function closeDirectoryPicker() {
    if (directoryPickerPurpose === "workspace-default") {
      cancelForm()
      return
    }
    directoryPickerOpen = false
    Qt.callLater(function() { browseButton.forceActiveFocus() })
  }

  function parentDirectory(path) {
    var value = String(path || "/").replace(/\/+$/, "")
    if (value === "") return "/"
    var separator = value.lastIndexOf("/")
    return separator <= 0 ? "/" : value.substring(0, separator)
  }

  function directoryDisplayName(path) {
    var value = String(path || "/").replace(/\/+$/, "")
    if (value === "" || value === "/") return "File System"
    if (value === home) return "Home"
    var separator = value.lastIndexOf("/")
    return separator < 0 ? value : value.substring(separator + 1)
  }

  function enterDirectory(path) {
    if (String(path || "").indexOf("/") !== 0) return
    directoryPickerPath = String(path)
    directoryPickerIndex = 0
  }

  function moveDirectorySelection(delta) {
    if (directoryModel.count === 0) return
    directoryPickerIndex = Math.max(0,
      Math.min(directoryPickerIndex + delta, directoryModel.count - 1))
    directoryList.positionViewAtIndex(directoryPickerIndex, ListView.Contain)
  }

  function enterSelectedDirectory() {
    if (directoryModel.count === 0) return
    enterDirectory(directoryModel.get(directoryPickerIndex, "filePath"))
  }

  function chooseDirectory() {
    var path = directoryPickerPath
    if (directoryPickerPurpose === "workspace-default") {
      submitWorkspaceDefaultPath(path)
      return
    }
    cwdField.text = path
    cwdIsExact = true
    directoryPickerOpen = false
    Qt.callLater(function() { cwdField.forceActiveFocus() })
  }

  function submitForm() {
    if (formMode === "project") {
      if (!online || !projectDiscoveryLoaded || !selectedProject) {
        actionMessage = "Select a discovered project or cancel"
        return
      }
      var projectPath = String(selectedProject.path)
      var projectName = String(selectedProject.name)
      cancelForm()
      requestGeneratedWorkspace(projectPath, projectName)
      return
    }
    if (actionProcess.running) return
    var name = nameField.text.trim()
    var cwd = cwdIsExact ? cwdField.text : cwdField.text.trim()
    if (name === "") {
      actionMessage = "A name is required"
      return
    }
    var blocked = WorkspaceModel.workspaceCreationBlockReason(
      workspaceDetail, eligibleCreationNodes.length)
    if (blocked !== "") {
      actionMessage = blocked
      return
    }
    var owner = creationNode
    if (globalWorkspacesAvailable && workspaceDetail && workspaceDetail.is_global && !owner) {
      actionMessage = "Select a Node for this Workspace resource"
      return
    }

    var command
    if (formMode === "shell" && workspaceDetail) {
      pendingAction = { kind: "create-shell", key: workspaceDetail.key + "\u001fnew:" + name,
        nodeId: owner.node_id }
      command = WorkspaceModel.shellCreateCommand(
        workspaceDetail, name, cwd, owner.node_id, [])
    } else if (formMode === "agent" && workspaceDetail) {
      var host = selectedAgentHost()
      if (!host) {
        actionMessage = "Select an available Agent host"
        return
      }
      pendingAction = { kind: "create-agent", key: workspaceDetail.key + "\u001fnew:" + name,
        nodeId: owner.node_id, hostName: host.label }
      pendingShell = { workspaceKey: workspaceDetail.key, nodeId: owner.node_id,
        name: name, armed: false }
      command = WorkspaceModel.shellCreateCommand(
        workspaceDetail, name, cwd, owner.node_id, agentHostCommand)
    } else {
      return
    }

    actionMessage = "Creating " + name + "..."
    actionProcess.command = command
    actionProcess.running = true
  }

  function processError(raw, fallback) {
    try {
      var response = JSON.parse(String(raw || ""))
      if (response.error && response.error.message) return String(response.error.message)
    } catch (exception) {
    }
    var message = String(raw || "").trim()
    return message !== "" ? message : fallback
  }

  function parseBoomuxRelease(raw) {
    try {
      var release = JSON.parse(String(raw || ""))
      latestBoomuxVersion = String(release.tag_name || "").replace(/^v/, "")
      latestBoomuxUrl = String(release.html_url || boomuxRepositoryUrl + "/releases")
    } catch (exception) {
      latestBoomuxVersion = ""
      latestBoomuxUrl = ""
    }
  }

  function parseLocalUpdateStatus(raw) {
    try {
      var data = parseEnvelope(raw, "update.status")
      latestBoomuxVersion = String(data.latest || "")
      latestBoomuxUrl = String(data.release_url || boomuxRepositoryUrl + "/releases")
      boomuxUpdateAction = String(data.recommended_action || "")
      if (localUpdateVerificationPending) {
        var current = String(data.current || "")
        if (localUpdateExpectedVersion !== ""
            && !WorkspaceModel.versionIsNewer(localUpdateExpectedVersion, current)) {
          localUpdateVerificationPending = false
          localUpdateVerificationTimer.stop()
          actionMessage = "Boomux updated to " + current
          showNotice("Boomux update complete", actionMessage,
            currentNoticeScreen(), false)
          refreshInstalledState()
        } else {
          continueLocalUpdateVerification()
        }
      }
    } catch (exception) {
      if (localUpdateVerificationPending) {
        continueLocalUpdateVerification()
        return
      }
      latestBoomuxVersion = ""
      latestBoomuxUrl = ""
      boomuxUpdateAction = ""
    }
  }

  function continueLocalUpdateVerification() {
    localUpdateVerificationAttempts++
    if (localUpdateVerificationAttempts >= 60) {
      localUpdateVerificationPending = false
      actionMessage = "Boomux update did not complete · run boomux update in a terminal to review the error"
      showNotice("Boomux update did not complete", actionMessage,
        currentNoticeScreen(), true)
    } else {
      localUpdateVerificationTimer.restart()
    }
  }

  function startLocalUpdate() {
    if (localUpdateProcess.running) return
    if (!guidedLocalUpdateSupported || boomuxUpdateAction !== "run_update") {
      Qt.openUrlExternally(latestBoomuxUrl || boomuxRepositoryUrl + "/releases")
      return
    }
    actionMessage = "Opening guided Boomux update..."
    localUpdateProcess.command = WorkspaceModel.guidedLocalUpdateCommand()
    localUpdateProcess.running = true
  }

  function parsePluginRelease(raw) {
    try {
      latestPluginVersion = String(JSON.parse(String(raw || "")).version || "")
    } catch (exception) {
      latestPluginVersion = ""
    }
  }

  function focusPane() {
    if (opened && panel.keyboardMode) {
      panel.exitKeyboardMode()
      return
    }
    if (!opened) open()
    Qt.callLater(function() {
      if (root.opened) panel.enterKeyboardMode()
    })
  }

  onOpenedChanged: if (opened) {
    refreshInstalledState()
    if (expandedWorkspaceKey === "") {
      var initialWorkspace = activeBoomuxWorkspace || selectedWorkspace
      if (initialWorkspace) expandedWorkspaceKey = initialWorkspace.key
    }
    positionActiveWorkspace()
  } else {
    workspacePositionTimer.stop()
    pendingWorkspacePositionKey = ""
    settingsOpen = false
    itemToRemove = null
    cancelForm()
  }

  Timer {
    id: workspacePositionTimer
    interval: 180
    repeat: false
    onTriggered: {
      var workspaceKey = root.pendingWorkspacePositionKey
      root.pendingWorkspacePositionKey = ""
      root.applyWorkspacePosition(workspaceKey)
    }
  }

  IpcHandler {
    target: root.ipcTarget

    function focus(): void { root.focusPane() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function releaseFocus(): void { panel.exitKeyboardMode() }
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!event || !event.name) return
      var name = String(event.name)
      if (name === "activespecial" || name === "activespecialv2" || name === "focusedmon")
        root.refreshDesktopWorkspace()
      if (name === "activewindow" || name === "activewindowv2" || name === "openwindow"
          || name === "closewindow" || name === "movewindow" || name === "movewindowv2")
        root.refreshDesktopTerminal()
    }
  }

  Process {
    id: desktopWorkspaceProcess
    command: ["hyprctl", "-j", "monitors"]
    onRunningChanged: {
      if (running) desktopWorkspaceTimeout.restart()
      else desktopWorkspaceTimeout.stop()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDesktopWorkspaceMonitors(text)
    }
    onExited: function() {
      if (!root.desktopWorkspaceRefreshPending) return
      root.desktopWorkspaceRefreshPending = false
      Qt.callLater(root.refreshDesktopWorkspace)
    }
  }

  Timer {
    id: desktopWorkspaceTimeout
    interval: 2000
    repeat: false
    onTriggered: {
      root.activeBoomuxWorkspaceId = ""
      desktopWorkspaceProcess.running = false
    }
  }

  Process {
    id: desktopTerminalProcess
    command: ["hyprctl", "-j", "activewindow"]
    onRunningChanged: {
      if (running) desktopTerminalTimeout.restart()
      else desktopTerminalTimeout.stop()
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseDesktopTerminal(text)
    }
    onExited: function() {
      if (!root.desktopTerminalRefreshPending) return
      root.desktopTerminalRefreshPending = false
      Qt.callLater(root.refreshDesktopTerminal)
    }
  }

  Timer {
    id: desktopTerminalTimeout
    interval: 2000
    repeat: false
    onTriggered: {
      root.activeBoomuxTerminalKey = ""
      desktopTerminalProcess.running = false
    }
  }

  Process {
    id: boomuxUpdateProcess
    command: ["curl", "--fail", "--silent", "--max-time", "5",
      "--max-filesize", "65536",
      "https://api.github.com/repos/gardnmi/boomux/releases/latest"]
    stdout: StdioCollector { id: boomuxUpdateStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseBoomuxRelease(boomuxUpdateStdout.text)
    }
  }

  Process {
    id: localUpdateStatusProcess
    command: ["boomux", "update", "status", "--json"]
    stdout: StdioCollector { id: localUpdateStatusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseLocalUpdateStatus(localUpdateStatusStdout.text)
      else if (root.localUpdateVerificationPending) root.continueLocalUpdateVerification()
      else boomuxUpdateProcess.running = true
    }
  }

  Timer {
    id: localUpdateVerificationTimer
    interval: 2000
    repeat: false
    onTriggered: {
      if (!root.localUpdateVerificationPending) return
      if (localUpdateStatusProcess.running) restart()
      else localUpdateStatusProcess.running = true
    }
  }

  Process {
    id: pluginUpdateProcess
    command: ["curl", "--fail", "--silent", "--max-time", "5",
      "--max-filesize", "65536",
      "https://raw.githubusercontent.com/gardnmi/omarchy-boomux/main/manifest.json"]
    stdout: StdioCollector { id: pluginUpdateStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parsePluginRelease(pluginUpdateStdout.text)
    }
  }

  Process {
    id: capabilityProcess
    command: ["boomux", "capabilities", "--json"]
    stdout: StdioCollector { id: capabilityStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseCapabilities(capabilityStdout.text)
      else {
        root.cliAvailable = false
        root.cliVersion = ""
        root.capabilitiesReady = true
        root.projectListSupported = false
        root.atomicWorkspaceCreationSupported = false
        root.workspaceDefaultCwdSupported = false
        root.federationSupported = false
        root.globalWorkspacesSupported = false
      }
    }
  }

  Process {
    id: webStatusProcess
    command: ["boomux", "web", "status", "--json"]
    stdout: StdioCollector { id: webStatusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      try {
        root.applyWebStatus(webStatusStdout.text, "web.status")
      } catch (exception) {
        console.warn("io.github.gardnmi.boomux:", exception)
      }
    }
  }

  Process {
    id: webStartProcess
    command: ["boomux", "web", "start", "--tailscale", "--json"]
    stdout: StdioCollector { id: webStartStdout; waitForEnd: true }
    stderr: StdioCollector { id: webStartStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          root.applyWebStatus(webStartStdout.text, "web.start")
          root.actionMessage = "Boomux Web is available through Tailscale"
        } catch (exception) {
          root.actionMessage = "Could not validate Boomux Web startup"
        }
      } else {
        root.actionMessage = root.processError(webStartStderr.text || webStartStdout.text,
          "Could not publish Boomux Web through Tailscale")
      }
      if (!webStatusProcess.running) webStatusProcess.running = true
    }
  }

  Process {
    id: webStopProcess
    command: ["boomux", "web", "stop", "--json"]
    stdout: StdioCollector { id: webStopStdout; waitForEnd: true }
    stderr: StdioCollector { id: webStopStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.webRunning = false
        root.webTailscale = false
        root.webDashboardUrl = ""
        root.webOpencodeUrl = ""
        root.actionMessage = "Boomux Web stopped"
      } else {
        root.actionMessage = root.processError(webStopStderr.text || webStopStdout.text,
          "Could not stop Boomux Web")
      }
      if (!webStatusProcess.running) webStatusProcess.running = true
    }
  }

  Process {
    id: projectListProcess
    command: ["boomux", "project", "list", "--json"]
    stdout: StdioCollector { id: projectListStdout; waitForEnd: true }
    stderr: StdioCollector { id: projectListStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var superseded = root.projectRefreshQueued
      var owner = root.nodeFor(root.projectActiveNodeId)
      var current = owner && WorkspaceModel.projectDiscoveryResponseCurrent(
        root.projectRequestedNodeId, root.projectActiveNodeId, owner.node_id)
      if (exitCode === 0 && !superseded) root.parseProjects(projectListStdout.text)
      else if (exitCode !== 0 && current && !superseded) {
        root.projects = []
        root.projectRootsConfigured = false
        root.projectDiscoveryLoaded = true
        root.projectLoadedNodeId = owner.node_id
        root.projectDiscoveryExpiresAt = Date.now() + 5000
        root.projectChooserRequested = false
        root.projectError = root.processError(projectListStderr.text || projectListStdout.text,
          "Could not discover configured projects")
      }
      if (superseded || (root.projectRequestedNodeId !== ""
          && root.projectRequestedNodeId !== root.projectActiveNodeId)) {
        root.projectRefreshQueued = false
        Qt.callLater(function() { root.startProjectDiscovery() })
      }
    }
  }

  Process {
    id: integrationStatusProcess
    stdout: StdioCollector { id: integrationStatusStdout; waitForEnd: true }
    stderr: StdioCollector { id: integrationStatusStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var current = root.formMode === "agent"
        && root.agentHostActiveNodeId === root.agentHostRequestedNodeId
      if (exitCode === 0 && current) {
        try {
          root.parseAgentHosts(integrationStatusStdout.text)
        } catch (exception) {
          root.agentHosts = []
          root.agentHostName = ""
          root.agentHostCommand = []
          root.agentHostError = "Could not validate available Agent hosts"
          console.warn("io.github.gardnmi.boomux:", exception)
        }
      } else if (exitCode !== 0 && current) {
        root.agentHostError = root.processError(
          integrationStatusStderr.text || integrationStatusStdout.text,
          "Could not discover available Agent hosts")
      }
      if (root.agentHostRequestedNodeId !== ""
          && root.agentHostRequestedNodeId !== root.agentHostActiveNodeId)
        Qt.callLater(function() { root.startAgentHostDiscovery() })
    }
  }

  Process {
    id: shellNameSuggestionProcess
    stdout: StdioCollector { id: shellNameSuggestionStdout; waitForEnd: true }
    stderr: StdioCollector { id: shellNameSuggestionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseShellNameSuggestion(shellNameSuggestionStdout.text)
      else console.warn("io.github.gardnmi.boomux:", root.processError(
        shellNameSuggestionStderr.text || shellNameSuggestionStdout.text,
        "Could not suggest a shell name"))
      if (root.suggestedNameRequestedIdentity
          && (!root.suggestedNameActiveIdentity
            || root.suggestedNameRequestedIdentity.key !== root.suggestedNameActiveIdentity.key))
        root.startShellNameSuggestion()
    }
  }

  Process {
    id: daemonStatusProcess
    command: ["boomux", "daemon", "status", "--json"]
    stdout: StdioCollector { id: daemonStatusStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var explicitCreationCheck = root.workspaceCreateStatusActive
      root.workspaceCreateStatusActive = false
      if (exitCode === 0) root.parseDaemonStatus(
        daemonStatusStdout.text, explicitCreationCheck)
      else if (explicitCreationCheck)
        root.failWorkspaceCreation("Could not check Boomux daemon status before creation")
      else root.setOffline("Boomux daemon is stopped")
      if (root.workspaceCreateStatusQueued && root.workspaceCreateRequested
          && !daemonStartProcess.running)
        Qt.callLater(function() { root.requestFreshWorkspaceCreateStatus() })
    }
  }

  Process {
    id: daemonStartProcess
    command: WorkspaceModel.workspaceDaemonStartCommand()
    stdout: StdioCollector { id: daemonStartStdout; waitForEnd: true }
    stderr: StdioCollector { id: daemonStartStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        Qt.callLater(function() { root.requestFreshWorkspaceCreateStatus() })
      } else {
        root.workspaceCreateRequested = null
        root.showActionFailure("Workspace creation unavailable", root.processError(
          daemonStartStderr.text || daemonStartStdout.text,
          "Could not start Boomux"))
      }
    }
  }

  Process {
    id: nodeSnapshotProcess
    command: ["boomux", "node", "snapshot", "--json"]
    stdout: StdioCollector { id: nodeSnapshotStdout; waitForEnd: true }
    stderr: StdioCollector { id: nodeSnapshotStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var explicitCreationSnapshot = root.workspaceCreateSnapshotActive
      root.workspaceCreateSnapshotActive = false
      root.finishRefresh()
      if (exitCode === 0) root.parseNodeSnapshot(
        nodeSnapshotStdout.text, explicitCreationSnapshot)
      else {
        root.error = root.processError(nodeSnapshotStderr.text || nodeSnapshotStdout.text,
          "Could not read federated Boomux state")
        if (explicitCreationSnapshot)
          root.failWorkspaceCreation("Could not obtain a fresh Boomux Node snapshot")
      }
      if (root.workspaceCreateSnapshotQueued && root.workspaceCreateRequested)
        Qt.callLater(function() { root.requestFreshWorkspaceCreateSnapshot() })
      if (root.focusRefreshPending) {
        root.focusRefreshPending = false
        Qt.callLater(function() { root.requestFocusedTerminalRefresh() })
      }
    }
  }

  Process {
    id: eventProcess
    stdout: StdioCollector { id: eventStdout; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        try {
          root.parseEvents(eventStdout.text)
        } catch (exception) {
          root.eventCursor = ""
          console.warn("io.github.gardnmi.boomux:", exception)
        }
        Qt.callLater(function() { root.startEventWait() })
      } else {
        root.eventCursor = ""
      }
    }
  }

  Process {
    id: workspaceListProcess
    command: ["boomux", "workspace", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseWorkspaces(text) }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode !== 0) {
        root.online = false
        root.workspaceTreeSnapshotSignature = ""
        root.workspaces = []
        root.workspaceTreeWorkspaces = []
        root.error = "Boomux is unavailable"
      }
    }
  }

  Process {
    id: listProcess
    command: ["boomux", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseShells(text) }
    onExited: function(exitCode) {
      root.finishRefresh()
      if (exitCode === 0 && !agentProcess.running) agentProcess.running = true
      else if (exitCode !== 0) {
        root.agents = []
        root.finishRefresh()
      }
    }
  }

  Process {
    id: agentProcess
    command: ["boomux", "agent", "list", "--json"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseAgents(text) }
    onExited: function(exitCode) { root.finishRefresh() }
  }


  Process {
    id: workspaceInspectProcess
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.parseWorkspaceDetail(text) }
    onExited: function(exitCode) {
      if (root.inspectRequestedKey !== "" && root.inspectRequestedKey !== root.inspectActiveKey)
        root.inspectWorkspace(root.inspectRequestedKey)
    }
  }

  Process {
    id: workspaceSelectionProcess
    stdout: StdioCollector { id: workspaceSelectionStdout; waitForEnd: true }
    stderr: StdioCollector { id: workspaceSelectionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var active = root.workspaceSelectionActive
      if (exitCode === 0 && active) {
        root.workspaceSelectionAppliedId = active.id
        root.actionMessage = active.id === ""
          ? "Default Workspace cleared"
          : "Default Workspace: " + active.name
      } else if (exitCode !== 0) {
        root.showActionFailure("Workspace selection failed", root.processError(
          workspaceSelectionStderr.text || workspaceSelectionStdout.text,
          "Could not select the default Workspace"))
      }
      root.workspaceSelectionActive = null
      if (root.workspaceSelectionRequested
          && root.workspaceSelectionRequested.id !== root.workspaceSelectionAppliedId)
        Qt.callLater(function() { root.startWorkspaceSelection() })
    }
  }

  Process {
    id: nodeShellProcess
    stdout: StdioCollector { id: nodeShellStdout; waitForEnd: true }
    stderr: StdioCollector { id: nodeShellStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionMessage = "Shell created on " + root.nodeShellAlias
        root.refresh()
      } else {
        root.actionMessage = root.processError(
          nodeShellStderr.text || nodeShellStdout.text,
          "Could not create a Shell on " + root.nodeShellAlias)
        root.showNotice("Shell creation failed", root.actionMessage,
          root.currentNoticeScreen(), true)
      }
    }
  }

  Process {
    id: nodeUpgradeProcess
    stdout: StdioCollector { id: nodeUpgradeStdout; waitForEnd: true }
    stderr: StdioCollector { id: nodeUpgradeStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionMessage = "Node update finished for " + root.nodeUpgradeAlias
        root.refresh()
      } else {
        root.showNotice("Node update failed", root.processError(
          nodeUpgradeStderr.text || nodeUpgradeStdout.text,
          "Could not update " + root.nodeUpgradeAlias), root.currentNoticeScreen(), true)
      }
    }
  }

  Process {
    id: nodeUninstallProcess
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionMessage = "Guided Node uninstall opened for " + root.nodeUninstallAlias
        root.showNotice("Uninstall and Forget",
          "Review the impact and confirm the uninstall in the terminal.",
          root.currentNoticeScreen(), true)
      } else {
        root.showNotice("Node uninstall failed",
          "The guided uninstall terminal could not be opened",
          root.currentNoticeScreen(), true)
      }
    }
  }

  Process {
    id: localUpdateProcess
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionMessage = "Boomux update running in terminal..."
        root.localUpdateExpectedVersion = root.latestBoomuxVersion
        root.localUpdateVerificationAttempts = 0
        root.localUpdateVerificationPending = true
        localUpdateVerificationTimer.restart()
        root.showNotice("Guided Boomux update opened",
          "Waiting for the installed version to change.",
          root.currentNoticeScreen(), false)
      } else {
        root.actionMessage = "Could not open the Boomux update terminal"
        root.showNotice("Boomux update failed",
          "The guided update terminal could not be opened", root.currentNoticeScreen(), true)
      }
    }
  }

  Process {
    id: nodeReauthenticateProcess
    stdout: StdioCollector { id: nodeReauthenticateStdout; waitForEnd: true }
    stderr: StdioCollector { id: nodeReauthenticateStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) {
        root.actionMessage = "Node authentication finished for "
          + root.nodeReauthenticateAlias
        root.refresh()
      } else {
        root.showNotice("Node authentication failed", root.processError(
          nodeReauthenticateStderr.text || nodeReauthenticateStdout.text,
          "Could not authenticate " + root.nodeReauthenticateAlias),
          root.currentNoticeScreen(), true)
      }
    }
  }

  Process {
    id: workspaceCreateProcess
    property string expectedNodeId: ""
    stdout: StdioCollector { id: workspaceCreateStdout; waitForEnd: true }
    stderr: StdioCollector { id: workspaceCreateStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.showActionFailure("Workspace creation failed", root.processError(
          workspaceCreateStderr.text || workspaceCreateStdout.text,
          "Could not create the Workspace"))
        return
      }
      try {
        root.pendingWorkspaceCreation = WorkspaceModel.atomicWorkspaceCreateIdentity(
          root.parseEnvelope(workspaceCreateStdout.text, "workspace.create"),
          expectedNodeId)
        root.pendingWorkspaceConfirmationDeadline = Date.now() + 10000
        root.actionMessage = "Waiting for the created Workspace snapshot..."
        root.refresh()
        root.scheduleMutationConfirmation()
      } catch (exception) {
        root.showActionFailure("Workspace creation failed",
          "Could not validate the created Workspace, placement, and Shell identities")
      }
    }
  }

  Process {
    id: defaultCwdProcess
    stdout: StdioCollector { id: defaultCwdStdout; waitForEnd: true }
    stderr: StdioCollector { id: defaultCwdStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var expected = root.defaultCwdRequest
      root.defaultCwdRequest = null
      if (exitCode !== 0) {
        root.showActionFailure("Shell start folder change failed", root.processError(
          defaultCwdStderr.text || defaultCwdStdout.text,
          "Could not change where new Shells start"))
        return
      }
      try {
        root.pendingDefaultCwd = WorkspaceModel.workspaceDefaultCwdIdentity(
          root.parseEnvelope(defaultCwdStdout.text, "workspace.set-default-cwd"), expected)
        root.pendingDefaultCwdConfirmationDeadline = Date.now() + 10000
        root.actionMessage = "Waiting for the updated Workspace snapshot..."
        root.refresh()
        root.scheduleMutationConfirmation()
      } catch (exception) {
        root.showActionFailure("Shell start folder change failed",
          "Could not validate the updated Workspace placement identity")
      }
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var pending = root.pendingAction
      var action = pending ? pending.kind : ""
      root.pendingAction = null
      if (exitCode !== 0) {
        root.pendingShell = null
        root.actionMessage = root.processError(actionStderr.text || actionStdout.text,
          action === "open-workspace" || action === "show-workspace"
            ? "Workspace open reported a warning"
            : "Boomux action failed")
        if ((action === "open-workspace" || action === "show-workspace")
            && pending.noticeScreen) {
          if (pending.availablePlacements > 0 && pending.unavailablePlacements > 0)
            root.showNotice("Workspace open warning", pending.unavailablePlacements + " placement"
              + (pending.unavailablePlacements === 1 ? "" : "s")
              + " unavailable; available items were attempted", pending.noticeScreen, true)
          else root.showNotice("Workspace open warning", root.actionMessage,
            pending.noticeScreen, true)
        } else root.showNotice("Boomux action failed", root.actionMessage,
          root.currentNoticeScreen(), true)
        Qt.callLater(function() { root.startPendingWorkspaceOpen() })
        return
      }
      if (action === "create-agent" && root.pendingShell)
        root.pendingShell = Object.assign({}, root.pendingShell, { armed: true })
      root.cancelForm()
      if (action === "create-shell") root.actionMessage = "Shell created"
      else if (action === "create-agent")
        root.actionMessage = "Starting " + String(pending.hostName || "Agent") + "..."
      else if (action === "invoke-launcher") root.actionMessage = "Launcher started"
      else if (action === "remove-launcher") root.actionMessage = "Launcher removed"
      else if (action === "remove-shell") root.actionMessage = "Shell closed"
      else if (action === "remove-workspace") root.actionMessage = "Workspace removed"
      else if (action === "rename-workspace") root.actionMessage = "Workspace renamed"
      else if (action === "rename-launcher") root.actionMessage = "Launcher renamed"
      else if (action === "rename-shell") root.actionMessage = "Shell renamed"
      else if (action === "forget-node") root.actionMessage = "Node forgotten"
      else if (action === "show-workspace") {
        root.workspaceSelectionAppliedId = pending.id
        root.actionMessage = ""
      } else {
        root.actionMessage = "Workspace opened"
        if (pending && pending.noticeScreen)
          root.showNotice("Workspace opened", pending.name,
            pending.noticeScreen, true)
      }
      root.refresh()
      Qt.callLater(function() { root.startPendingWorkspaceOpen() })
    }
  }

  Process {
    id: openProcess
    onExited: function(exitCode) {
      var agent = root.pendingOpenAgent
      root.pendingOpenAgent = null
      root.pendingOpenKey = ""
      root.pendingOpenRunKey = ""
      if (exitCode !== 0) {
        root.showActionFailure("Terminal open failed", "Could not open terminal")
        return
      }
      if (agent) {
        root.clearCompletedAgent(agent.key)
        root.acknowledgeAgent(agent)
      }
      root.actionMessage = ""
    }
  }

  Process {
    id: acknowledgeProcess
    stdout: StdioCollector { id: acknowledgeStdout; waitForEnd: true }
    stderr: StdioCollector { id: acknowledgeStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var dismissed = root.activeAcknowledgement && root.activeAcknowledgement.dismissed
      var automatic = root.activeAcknowledgement && root.activeAcknowledgement.automatic
      var validResponse = false
      if (exitCode === 0 && root.activeAcknowledgement) {
        try {
          validResponse = WorkspaceModel.acknowledgementResponseMatches(
            root.parseEnvelope(acknowledgeStdout.text, "attention.acknowledge"),
            root.activeAcknowledgement)
        } catch (exception) {
          validResponse = false
        }
      }
      if (exitCode !== 0 || !validResponse) {
        var failure = exitCode !== 0
          ? root.processError(acknowledgeStderr.text || acknowledgeStdout.text,
            dismissed ? "Could not dismiss Agent notification"
              : (automatic ? "Could not clear resumed Agent attention" : "Could not acknowledge Agent attention"))
          : "Could not validate the acknowledged Agent identity"
        root.showActionFailure("Agent attention failed", failure)
      } else if (root.opened && !automatic)
        root.actionMessage = dismissed ? "Agent notification dismissed" : "Agent attention acknowledged"
      var queue = root.acknowledgeQueue.slice()
      if (queue.length > 0) queue.shift()
      root.acknowledgeQueue = queue
      root.activeAcknowledgement = null
      root.refresh()
      root.startNextAcknowledgement()
    }
  }

  FolderListModel {
    id: directoryModel
    folder: root.directoryPickerOpen ? Util.fileUrl(root.directoryPickerPath || root.home) : ""
    showDirs: true
    showFiles: false
    showDotAndDotDot: false
    showHidden: false
    showOnlyReadable: true
    sortField: FolderListModel.Name
    sortReversed: false
    caseSensitive: false
    onCountChanged: root.directoryPickerIndex = Math.max(0,
      Math.min(root.directoryPickerIndex, count - 1))
  }

  FileView {
    id: pluginManifest
    path: Qt.resolvedUrl("manifest.json")
    blockLoading: true
    printErrors: false
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      root.clockNow = Date.now()
      root.refresh()
    }
  }

  Timer {
    id: mutationConfirmationTimer
    interval: 1000
    repeat: false
    onTriggered: root.continueMutationConfirmation()
  }

  Timer {
    id: noticeTimer
    interval: 2200
    onTriggered: {
      root.noticeVisible = false
      root.noticeProtectedUntil = 0
    }
  }

  PanelWindow {
    id: noticeWindow
    screen: root.noticeScreen
    visible: root.noticeVisible && root.noticeScreen !== null
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omarchy-boomux-notice"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    BorderSurface {
      width: Style.space(250)
      implicitHeight: noticeColumn.implicitHeight + Style.space(20)
      x: root.paneSide === "left"
        ? panel.sideInset + Style.space(18)
        : parent.width - width - panel.sideInset - Style.space(18)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(18)
      color: Util.alpha(Color.background, 0.97)
      borderSpec: Border.surfaceSpec("popups", "border", Color.popups.border,
        Math.max(1, Style.normalBorderWidth))
      radius: Style.cornerRadius

      Column {
        id: noticeColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Style.space(12)
        anchors.rightMargin: Style.space(12)
        spacing: Style.space(3)

        Text {
          width: parent.width
          text: root.noticeTitle
          color: Color.popups.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: root.noticeDetail
          color: Util.alpha(Color.popups.text, 0.72)
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }
  }

  Grid {
    id: desktopIndicator
    columns: button.vertical ? 1 : 3
    columnSpacing: workspaceNameContainer.visible || terminalNameContainer.visible ? Style.space(6) : 0
    rowSpacing: workspaceNameContainer.visible || terminalNameContainer.visible ? Style.space(6) : 0

    BarIconButton {
      id: button
      bar: root.bar
      iconComponent: Component {
        Item {
          anchors.fill: parent
          BoomuxIcon {
            anchors.fill: parent
            color: root.blockedCount > 0 ? root.urgent
              : ((root.completedCount > 0 || root.updateAvailable) ? Color.accent : root.foreground)
            lit: root.blockedCount > 0 || root.completedCount > 0
          }
          Text {
            visible: root.blockedCount > 0 || root.completedCount > 0 || root.updateAvailable
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: root.blockedCount > 0 ? String(root.blockedCount)
              : (root.completedCount > 0 ? String(root.completedCount) : "↑")
            color: root.blockedCount > 0 ? root.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Math.max(7, Math.round(parent.height * 0.42))
            font.bold: true
          }
        }
      }
      active: root.blockedCount > 0 || root.completedCount > 0 || root.updateAvailable
      tooltipText: root.activeBoomuxTerminal && root.activeBoomuxTerminalWorkspace
        ? "Boomux Shell: " + root.activeBoomuxTerminal.name + " · Workspace: "
          + root.activeBoomuxTerminalWorkspace.name
        : (root.activeBoomuxWorkspaceName !== ""
        ? "Boomux Workspace: " + root.activeBoomuxWorkspaceName
        : (root.updateAvailable ? "Update available"
        : (root.online
        ? root.visibleAgents.length + " agents · " + root.workspaces.length + " workspaces"
        : "Boomux unavailable"
        )))
      onPressed: function(buttonCode) {
        if (buttonCode === Qt.RightButton) root.refreshInstalledState()
        else root.toggle()
      }
    }

    Item {
      id: workspaceNameContainer
      visible: root.activeBoomuxWorkspaceName !== ""
      width: visible ? (button.vertical ? button.implicitWidth
        : Math.min(workspaceName.implicitWidth, Style.space(140))) : 0
      height: visible ? (button.vertical
        ? Math.min(workspaceName.implicitWidth, Style.space(140)) : button.implicitHeight) : 0

      MouseArea {
        id: workspaceNameMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openWorkspacePanel(root.activeBoomuxWorkspace)
      }

      Text {
        id: workspaceName
        anchors.centerIn: parent
        width: button.vertical ? parent.height : parent.width
        height: button.vertical ? parent.width : parent.height
        rotation: button.vertical ? 90 : 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.activeBoomuxWorkspaceName
        color: workspaceNameMouse.containsMouse ? Color.accent : root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }
    }


    Item {
      id: terminalNameContainer
      visible: root.activeBoomuxTerminalLabel !== ""
      width: visible ? (button.vertical ? button.implicitWidth
        : Math.min(terminalName.implicitWidth, Style.space(180))) : 0
      height: visible ? (button.vertical
        ? Math.min(terminalName.implicitWidth, Style.space(180)) : button.implicitHeight) : 0

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.openWorkspacePanel(root.activeBoomuxTerminalWorkspace)
      }

      Text {
        id: terminalName
        anchors.centerIn: parent
        width: button.vertical ? parent.height : parent.width
        height: button.vertical ? parent.width : parent.height
        rotation: button.vertical ? 90 : 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: root.activeBoomuxTerminalLabel
        color: Color.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
  }

  SidePane {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    side: root.paneSide
    paneWidth: root.paneWidth
    focusColor: root.urgent
    focusTarget: keyCatcher

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.editing || root.settingsOpen || root.renameTarget !== null
      onMoveRequested: function(dx, dy) {
        if (root.itemToRemove && (dx !== 0 || dy !== 0))
          removeItemDialog.selectedIndex = removeItemDialog.selectedIndex === 0 ? 1 : 0
        else root.movePanelCursor(dx, dy)
      }
      onActivateRequested: {
        if (root.itemToRemove) {
          if (removeItemDialog.selectedIndex === 0) root.cancelRemoveItem()
          else root.confirmRemoveItem()
        } else root.activatePanelCursor()
      }
      onCloseRequested: {
        if (root.itemToRemove) root.cancelRemoveItem()
        else if (root.actionMenuTarget) root.closeActionMenu()
        else if (root.settingsOpen) root.hideSettings()
        else root.close()
      }
      onTabRequested: function(direction) {
        if (root.itemToRemove)
          removeItemDialog.selectedIndex = removeItemDialog.selectedIndex === 0 ? 1 : 0
        else if (root.actionMenuTarget) root.moveActionMenu(direction)
        else root.cycleFocusSection(direction)
      }
      onTextKey: function(text) {
        if (root.itemToRemove || root.actionMenuTarget) return
        if (text === "r" || text === "R") root.refreshInstalledState()
        else if (text === "1") root.selectTab("agents")
        else if (text === "2") root.selectTab("nodes")
        else if (text === "m" || text === "M") root.showCursorActionMenu()
        else if ((text === "a" || text === "A") && root.activeTab === "nodes"
            && root.federationAvailable) root.createNode()
        else if (text === "n" || text === "N") root.requestGeneratedWorkspace(root.home)
        else if ((text === "d" || text === "D") && root.activeTab === "agents")
          root.dismissAgent(root.selectedItem)
      }

      Flickable {
        id: settingsScroll
        visible: root.settingsOpen
        anchors.fill: parent
        contentHeight: settingsColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        Keys.onEscapePressed: root.hideSettings()

        Column {
          id: settingsColumn
          width: settingsScroll.width
          spacing: Style.space(12)

        Row {
          width: parent.width
          height: Style.space(36)
          Text {
            width: parent.width - settingsBackButton.width
            anchors.verticalCenter: parent.verticalCenter
            text: "BOOMUX SETTINGS"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Button {
            id: settingsBackButton
            width: Style.space(34)
            height: Style.space(30)
            text: "×"
            tooltipText: "Back to Boomux"
            bordered: true
            focusable: true
            KeyNavigation.tab: settingsLeftButton
            KeyNavigation.backtab: settingsConfigButton
            onActiveFocusChanged: root.revealSettingsItem(settingsBackButton)
            foreground: root.foreground
            onClicked: root.hideSettings()
          }
        }

        PanelSectionHeader {
          width: parent.width
          text: "PANE SIDE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          Button {
            id: settingsLeftButton
            width: (parent.width - parent.spacing) / 2
            text: "Left"
            selected: root.paneSide === "left"
            bordered: true
            focusable: true
            KeyNavigation.tab: settingsRightButton
            KeyNavigation.backtab: settingsBackButton
            onActiveFocusChanged: root.revealSettingsItem(settingsLeftButton)
            foreground: root.foreground
            onClicked: root.persistPaneSettings({ side: "left" })
          }
          Button {
            id: settingsRightButton
            width: (parent.width - parent.spacing) / 2
            text: "Right"
            selected: root.paneSide === "right"
            bordered: true
            focusable: true
            KeyNavigation.tab: settingsWidthDownButton
            KeyNavigation.backtab: settingsLeftButton
            onActiveFocusChanged: root.revealSettingsItem(settingsRightButton)
            foreground: root.foreground
            onClicked: root.persistPaneSettings({ side: "right" })
          }
        }

        PanelSectionHeader {
          width: parent.width
          text: "PANE WIDTH"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }
        Row {
          width: parent.width
          spacing: Style.space(8)
          Button {
            id: settingsWidthDownButton
            width: Style.space(42)
            text: "−"
            bordered: true
            focusable: true
            KeyNavigation.tab: settingsWidthUpButton
            KeyNavigation.backtab: settingsRightButton
            onActiveFocusChanged: root.revealSettingsItem(settingsWidthDownButton)
            enabled: root.paneWidth > Style.space(280)
            foreground: root.foreground
            onClicked: root.persistPaneSettings({ paneWidth: root.paneWidth - 20 })
          }
          Text {
            width: parent.width - Style.space(84) - parent.spacing * 2
            height: Style.space(34)
            text: root.paneWidth + " px"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          Button {
            id: settingsWidthUpButton
            width: Style.space(42)
            text: "+"
            bordered: true
            focusable: true
            KeyNavigation.tab: settingsConfigButton
            KeyNavigation.backtab: settingsWidthDownButton
            onActiveFocusChanged: root.revealSettingsItem(settingsWidthUpButton)
            enabled: root.paneWidth < Style.space(520)
            foreground: root.foreground
            onClicked: root.persistPaneSettings({ paneWidth: root.paneWidth + 20 })
          }
        }

        PanelSeparator { foreground: root.foreground }

        Button {
          id: settingsConfigButton
          width: parent.width
          text: "Open Boomux config"
          iconText: ""
          tooltipText: "Run boomux config edit in a native terminal"
          bordered: true
          focusable: true
          KeyNavigation.tab: settingsBackButton
          KeyNavigation.backtab: settingsWidthUpButton
          onActiveFocusChanged: root.revealSettingsItem(settingsConfigButton)
          enabled: root.cliAvailable
          foreground: root.foreground
          onClicked: root.openBoomuxConfig()
        }
        }
      }

      Flickable {
        id: contentScroll
        visible: !root.settingsOpen
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: contentColumn
          width: Math.max(0, contentScroll.width - Style.space(8))
          spacing: Style.space(10)

        Row {
          width: parent.width
          height: Style.space(42)
          spacing: Style.space(8)

          BoomuxIcon {
            width: Style.space(26)
            height: Style.space(26)
            anchors.verticalCenter: parent.verticalCenter
            color: root.blockedCount > 0 ? root.urgent
              : (root.completedCount > 0 ? Color.accent : root.foreground)
            lit: root.blockedCount > 0 || root.completedCount > 0
          }
          Column {
            width: parent.width - headerActions.width - Style.space(34)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Text {
              id: boomuxHeaderTitle
              width: parent.width
              text: "BOOMUX"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: (root.cliVersion !== "" ? "v" + root.cliVersion + " · " : "")
                + (root.activeBoomuxWorkspaceName !== ""
                  ? "active · " + root.activeBoomuxWorkspaceName
                  : (root.online ? root.workspaces.length + " Workspaces" : "offline"))
              color: root.activeBoomuxWorkspaceName !== "" ? Color.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
          Row {
            id: headerActions
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(3)
            Button {
              width: Style.space(30)
              height: Style.space(30)
              iconText: ""
              tooltipText: "Open Boomux settings"
              bordered: true
              foreground: root.foreground
              horizontalPadding: Style.space(3)
              verticalPadding: Style.space(1)
              onClicked: root.showSettings()
            }
            Button {
              width: Style.space(30)
              height: Style.space(30)
              text: "×"
              tooltipText: "Close Boomux pane"
              bordered: true
              foreground: root.foreground
              horizontalPadding: Style.space(3)
              verticalPadding: Style.space(1)
              onClicked: root.close()
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Item {
          visible: root.updateAvailable
          width: parent.width
          implicitHeight: updateColumn.implicitHeight

          Column {
            id: updateColumn
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              width: parent.width
              text: "UPDATES AVAILABLE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Button {
              visible: root.boomuxUpdateAvailable
              width: parent.width
              text: "Boomux " + root.cliVersion + " → " + root.latestBoomuxVersion
              iconText: root.guidedLocalUpdateSupported
                && root.boomuxUpdateAction === "run_update" ? "↑" : "↗"
              tooltipText: root.guidedLocalUpdateSupported
                && root.boomuxUpdateAction === "run_update"
                ? "Open the guided Boomux update"
                : (root.boomuxUpdateAction === "use_package_manager"
                  ? "Update with the package manager that installed Boomux"
                : "Open the latest Boomux release"
                )
              bordered: true
              foreground: root.foreground
              enabled: !localUpdateProcess.running
              onClicked: root.startLocalUpdate()
            }
            Text {
              visible: root.boomuxUpdateAvailable
                && root.boomuxUpdateAction === "use_package_manager"
              width: parent.width
              text: "Update with the AUR or package helper that installed Boomux."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.Wrap
            }
            Button {
              visible: root.pluginUpdateAvailable
              width: parent.width
              text: "Plugin " + root.pluginVersion + " → " + root.latestPluginVersion
              iconText: "↗"
              tooltipText: "Open the Boomux plugin repository"
              bordered: true
              foreground: root.foreground
              onClicked: Qt.openUrlExternally(root.pluginRepositoryUrl)
            }
          }
        }

        Item {
          visible: root.capabilitiesReady && !root.cliAvailable
          width: parent.width
          implicitHeight: installColumn.implicitHeight

          Column {
            id: installColumn
            width: parent.width
            spacing: Style.space(8)

            PanelSectionHeader {
              width: parent.width
              text: "BOOMUX REQUIRED"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              width: parent.width
              text: "Boomux is not installed or is unavailable on PATH. Install it to manage persistent Workspaces and Agents."
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
            }
            Text {
              width: parent.width
              text: root.boomuxRepositoryUrl
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
              elide: Text.ElideMiddle
            }
            Button {
              width: parent.width
              text: "Open Install Page"
              iconText: "↗"
              bordered: true
              active: true
              foreground: root.foreground
              onClicked: Qt.openUrlExternally(root.boomuxRepositoryUrl)
            }
          }
        }

        Item {
          visible: root.cliAvailable && root.editing
          width: parent.width
          implicitHeight: formColumn.implicitHeight

          Column {
            id: formColumn
            width: parent.width
            spacing: Style.space(6)
            PanelSectionHeader {
              width: parent.width
              text: root.directoryPickerOpen
                ? (root.directoryPickerPurpose === "workspace-default"
                  ? "SHELL START FOLDER" : "CHOOSE DIRECTORY")
                : (root.formMode === "project" ? "FROM PROJECTS"
                  : (root.formMode === "shell" ? "CREATE SHELL" : "START AGENT"))
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Column {
              visible: root.directoryPickerOpen
              width: parent.width
              spacing: Style.space(6)

              Item {
                id: directoryPickerKeyHandler
                width: 1
                height: 1
                focus: root.directoryPickerOpen
                Keys.onPressed: function(event) {
                  if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
                    root.moveDirectorySelection(1)
                  } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
                    root.moveDirectorySelection(-1)
                  } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter
                      || event.key === Qt.Key_Right) {
                    root.enterSelectedDirectory()
                  } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backspace) {
                    root.enterDirectory(root.parentDirectory(root.directoryPickerPath))
                  } else if (event.key === Qt.Key_Space) {
                    root.chooseDirectory()
                  } else if (event.key === Qt.Key_Escape) {
                    root.closeDirectoryPicker()
                  } else if (event.key === Qt.Key_Tab) {
                    directoryChooseButton.forceActiveFocus()
                  } else if (event.key === Qt.Key_Backtab) {
                    directoryCancelButton.forceActiveFocus()
                  } else {
                    return
                  }
                  event.accepted = true
                }
              }

              Text {
                width: parent.width
                text: root.directoryPickerPurpose === "workspace-default"
                  ? "Choose where new Shells in this Workspace should start. Existing Shells stay where they are."
                  : "Choose the folder where this new item should start."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }

              Rectangle {
                width: parent.width
                height: Style.space(58)
                radius: Style.cornerRadius
                color: Util.alpha(root.foreground, 0.05)
                border.width: 1
                border.color: Util.alpha(root.foreground, 0.16)

                Row {
                  anchors.fill: parent
                  anchors.margins: Style.space(9)
                  spacing: Style.space(8)

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                  }

                  Column {
                    width: parent.width - Style.space(30)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      width: parent.width
                      text: root.directoryDisplayName(root.directoryPickerPath)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: root.directoryPickerPath
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }
                }
              }

              Text {
                width: parent.width
                text: "Open folders until the location above is right, then confirm it below."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
              }

              Item {
                width: parent.width
                height: Style.space(190)

                Text {
                  visible: directoryModel.count === 0
                  anchors.centerIn: parent
                  text: "No readable subdirectories"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                }

                ListView {
                  id: directoryList
                  anchors.fill: parent
                  model: directoryModel
                  spacing: Style.space(3)
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds
                  ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                  delegate: Rectangle {
                    required property string fileName
                    required property string filePath
                    required property int index
                    width: ListView.view.width
                    height: Style.space(40)
                    radius: Style.cornerRadius
                    color: index === root.directoryPickerIndex
                      ? Style.selectedFillFor(root.foreground, Color.accent)
                      : (directoryMouse.containsMouse
                        ? Util.alpha(root.foreground, 0.06) : "transparent")
                    Row {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.margins: Style.space(9)
                      anchors.verticalCenter: parent.verticalCenter
                      spacing: Style.space(8)
                      Text {
                        text: ""
                        color: index === root.directoryPickerIndex ? Color.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                      Text {
                        width: Math.max(0, parent.width - Style.space(52))
                        text: fileName
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                        elide: Text.ElideRight
                      }
                      Text {
                        text: "›"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.body
                      }
                    }
                    MouseArea {
                      id: directoryMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      onEntered: root.directoryPickerIndex = index
                      onClicked: root.enterDirectory(filePath)
                    }
                  }
                }
              }

              Button {
                id: directoryChooseButton
                width: parent.width
                text: root.directoryPickerPurpose === "workspace-default"
                  ? "Start New Shells Here" : "Use This Folder"
                focusable: true
                bordered: true
                active: true
                foreground: root.foreground
                onClicked: root.chooseDirectory()
              }

              Row {
                width: parent.width
                spacing: Style.space(6)
                Button {
                  width: (parent.width - parent.spacing) / 2
                  text: "Go Up"
                  focusable: true
                  bordered: true
                  enabled: root.directoryPickerCanGoUp
                  foreground: root.foreground
                  onClicked: root.enterDirectory(root.parentDirectory(root.directoryPickerPath))
                }
                Button {
                  id: directoryCancelButton
                  width: (parent.width - parent.spacing) / 2
                  text: "Cancel"
                  focusable: true
                  bordered: true
                  foreground: root.foreground
                  onClicked: root.closeDirectoryPicker()
                }
              }
            }

            Column {
              visible: !root.directoryPickerOpen && root.globalWorkspacesAvailable
                && (root.formMode === "shell" || root.formMode === "agent")
              width: parent.width
              spacing: Style.space(3)

              Dropdown {
                id: creationNodeDropdown
                visible: root.formMode === "shell" || root.formMode === "agent"
                width: parent.width
                label: "Select Node"
                value: root.creationNodeId
                options: root.eligibleCreationNodes.map(function(node) {
                  return {
                    value: String(node.node_id),
                    label: String(node.alias) + (node.local ? " · local" : " · remote")
                  }
                })
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(value) { root.selectCreationNode(value) }
              }

              Text {
                visible: root.creationNode && !root.creationNode.local
                width: parent.width
                text: root.creationNode ? "Remote Node: " + String(root.creationNode.alias)
                  + " · paths and commands run on that Node" : ""
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
              }

            }

            Column {
              visible: !root.directoryPickerOpen && root.formMode === "project"
              width: parent.width
              spacing: Style.space(6)

              TextField {
                id: projectSearchField
                width: parent.width
                placeholderText: "Search configured projects"
                foreground: root.foreground
                onTextChanged: root.projectQuery = text
                onAccepted: root.submitForm()
                Keys.onDownPressed: function(event) {
                  root.moveProjectSelection(1)
                  event.accepted = true
                }
                Keys.onUpPressed: function(event) {
                  root.moveProjectSelection(-1)
                  event.accepted = true
                }
                Keys.onTabPressed: function(event) {
                  projectCancelButton.forceActiveFocus()
                  event.accepted = true
                }
                Keys.onEscapePressed: root.cancelForm()
              }

              Text {
                visible: root.visibleProjects.length === 0
                width: parent.width
                text: projectListProcess.running ? "Discovering projects..."
                  : (root.projectError !== "" ? root.projectError
                    : (root.projectRootsConfigured ? "No projects match. Cancel to return."
                      : "No project roots configured. Cancel to return."))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 4
                elide: Text.ElideRight
                topPadding: Style.space(14)
                bottomPadding: Style.space(14)
              }

              ListView {
                id: projectList
                visible: root.visibleProjects.length > 0
                width: parent.width
                implicitHeight: Math.min(contentHeight, Style.space(180))
                model: root.visibleProjects
                spacing: Style.space(3)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                  required property var modelData
                  required property int index
                  width: ListView.view.width
                  height: Style.space(56)
                  radius: Style.cornerRadius
                  color: index === root.selectedProjectIndex
                    ? Style.selectedFillFor(root.foreground, Color.accent)
                    : (projectMouse.containsMouse
                      ? Util.alpha(root.foreground, 0.06) : "transparent")
                  border.width: index === root.selectedProjectIndex ? 1 : 0
                  border.color: Color.accent
                  Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: Style.space(9)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(1)
                    Text {
                      width: parent.width
                      text: String(modelData.name)
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: index === root.selectedProjectIndex
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: String(modelData.group) + " · " + root.compactPath(modelData.path)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }
                  MouseArea {
                    id: projectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root.selectedProjectIndex = index
                    onDoubleClicked: {
                      root.selectedProjectIndex = index
                      root.submitForm()
                    }
                  }
                }
              }

              Text {
                visible: root.visibleProjects.length > 0 && root.projectError !== ""
                width: parent.width
                text: root.projectError
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
              }
            }

            TextField {
              id: nameField
              visible: !root.directoryPickerOpen
                && (root.formMode === "shell" || root.formMode === "agent")
              width: parent.width
              placeholderText: "Shell name"
              foreground: root.foreground
              onTextEdited: root.nameFieldEdited = true
              onAccepted: {
                cwdField.forceActiveFocus()
              }
              Keys.onEscapePressed: root.cancelForm()
            }
            Row {
              visible: !root.directoryPickerOpen
                && (root.formMode === "shell" || root.formMode === "agent")
              width: parent.width
              spacing: Style.space(6)
              TextField {
                id: cwdField
                width: parent.width - browseButton.width - parent.spacing
                placeholderText: "Directory (optional)"
                foreground: root.foreground
                onTextEdited: root.cwdIsExact = false
                onAccepted: root.submitForm()
                Keys.onEscapePressed: root.cancelForm()
              }
              Button {
                id: browseButton
                width: Style.space(88)
                text: "Browse"
                tooltipText: "Choose a directory"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.openDirectoryPicker()
                enabled: root.creationNode && root.creationNode.local
              }
            }
            Column {
              visible: !root.directoryPickerOpen && root.formMode === "agent"
              width: parent.width
              spacing: Style.space(6)

              Dropdown {
                id: agentHostDropdown
                width: parent.width
                label: "Select Agent"
                value: root.agentHostName
                options: root.agentHosts.map(function(host) {
                  return { value: host.name, label: host.label + " · available" }
                })
                foreground: root.foreground
                fontFamily: root.fontFamily
                onChanged: function(value) { root.selectAgentHost(value) }
              }

              Text {
                visible: root.agentHosts.length === 0
                width: parent.width
                text: integrationStatusProcess.running
                  ? "Discovering available Agent hosts..." : root.agentHostError
                color: root.agentHostError !== "" ? root.urgent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
              }
            }
            Row {
              visible: !root.directoryPickerOpen
                && root.formMode !== "default-path"
              width: parent.width
              spacing: Style.space(6)
              Button {
                id: projectCancelButton
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                focusable: true
                bordered: true
                foreground: root.foreground
                onClicked: root.cancelForm()
              }
              Button {
                width: (parent.width - parent.spacing) / 2
                text: root.formMode === "agent" ? "Create & Open"
                  : (root.formMode === "project" ? "Create Workspace" : "Create")
                bordered: true
                focusable: true
                active: true
                enabled: !actionProcess.running && root.formCanSubmit()
                foreground: root.foreground
                onClicked: root.submitForm()
              }
            }
          }
        }

        Item {
          visible: root.cliAvailable && !root.editing
          width: parent.width
          implicitHeight: workspaceTreeColumn.implicitHeight

          Column {
            id: workspaceTreeColumn
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              height: Style.space(30)
              PanelSectionHeader {
                width: parent.width - workspaceCreateActions.width
                anchors.verticalCenter: parent.verticalCenter
                text: "WORKSPACES"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Row {
                id: workspaceCreateActions
                spacing: Style.space(5)
                Button {
                  id: fromProjectsButton
                  visible: root.online && root.projectListSupported
                    && root.projectRootsConfigured
                  width: Style.space(32)
                  height: Style.space(28)
                  iconText: ""
                  tooltipText: "Create a Workspace from a configured project"
                  bordered: true
                  enabled: !root.workspaceMutationBusy()
                  foreground: root.foreground
                  horizontalPadding: Style.space(3)
                  verticalPadding: Style.space(1)
                  onClicked: root.showProjectChooser()
                }
                Button {
                  id: createWorkspaceTreeButton
                  width: Style.space(32)
                  height: Style.space(28)
                  text: "+"
                  tooltipText: "Create a generated Workspace in HOME"
                  bordered: true
                  enabled: !root.workspaceMutationBusy()
                  foreground: root.foreground
                  horizontalPadding: Style.space(3)
                  verticalPadding: Style.space(1)
                  onClicked: root.requestGeneratedWorkspace(root.home)
                }
              }
            }

            Text {
              visible: root.visibleWorkspaces.length === 0
              width: parent.width
              text: root.error !== "" ? root.error : "No Boomux Workspaces"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(16)
              bottomPadding: Style.space(16)
            }

            ListView {
              id: workspaceTreeList
              visible: root.visibleWorkspaces.length > 0
              width: parent.width
              height: root.workspaceTreeHeight
              model: root.workspaceTreeWorkspaces
              spacing: Style.space(3)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Rectangle {
                id: workspaceTreeDelegate
                required property var modelData
                required property int index
                readonly property bool workspaceActive: modelData.is_global
                  && modelData.id === root.activeBoomuxWorkspaceId
                readonly property bool workspaceExpanded:
                  modelData.key === root.expandedWorkspaceKey
                readonly property bool workspaceDefault: modelData.is_global
                  && modelData.id === root.workspaceSelectionAppliedId
                readonly property bool cursorSelected: root.focusSection === "workspaces"
                  && index === root.selectedWorkspaceIndex
                readonly property var treeItems: WorkspaceModel.workspaceTreeItems(modelData)
                readonly property int visibleShellCount: modelData.shells
                  ? treeItems.filter(function(item) { return item.kind !== "launcher" }).length
                  : WorkspaceModel.userShellCount(root.shells, modelData.node_id, modelData.id)
                readonly property int rowHeight: Style.space(48)
                function revealTreeItem(itemIndex) {
                  var item = treeItemRepeater.itemAt(itemIndex)
                  if (!item) return
                  var point = item.mapToItem(workspaceTreeList.contentItem, 0, 0)
                  var maximumY = Math.max(0,
                    workspaceTreeList.contentHeight - workspaceTreeList.height)
                  if (point.y < workspaceTreeList.contentY)
                    workspaceTreeList.contentY = Math.max(0, point.y)
                  else if (point.y + item.height > workspaceTreeList.contentY
                      + workspaceTreeList.height)
                    workspaceTreeList.contentY = Math.min(maximumY,
                      point.y + item.height - workspaceTreeList.height)
                }
                width: ListView.view.width
                height: rowHeight + (workspaceExpanded ? childColumn.implicitHeight : 0)
                radius: Style.cornerRadius
                color: workspaceActive
                  ? Util.alpha(Color.accent, 0.16)
                  : (cursorSelected ? root.keyboardCursorFill
                  : (workspaceExpanded ? Util.alpha(root.foreground, 0.055)
                    : (workspaceRowMouse.containsMouse
                      ? Util.alpha(root.foreground, 0.04) : "transparent")))
                clip: true

                Behavior on height {
                  NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
                }

                Rectangle {
                  visible: workspaceTreeDelegate.workspaceActive
                  x: root.paneSide === "left" ? 0 : parent.width - width
                  width: Style.space(3)
                  height: workspaceTreeDelegate.rowHeight
                  color: Color.accent
                  radius: width / 2
                }

                Item {
                  id: expansionTarget
                  width: Style.space(28)
                  height: workspaceTreeDelegate.rowHeight
                  anchors.left: parent.left

                  Text {
                    anchors.centerIn: parent
                    text: workspaceTreeDelegate.workspaceExpanded ? "▾" : "▸"
                    color: workspaceTreeDelegate.workspaceExpanded ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.focusSection = "workspaces"
                      root.selectedWorkspaceIndex = workspaceTreeDelegate.index
                      root.selectedWorkspaceItemIndex = 0
                      root.toggleWorkspaceExpansion(workspaceTreeDelegate.modelData)
                    }
                  }
                }

                Rectangle {
                  id: workspaceStateDot
                  anchors.left: expansionTarget.right
                  anchors.leftMargin: Style.space(2)
                  anchors.verticalCenter: expansionTarget.verticalCenter
                  width: Style.space(7)
                  height: width
                  radius: width / 2
                  color: workspaceTreeDelegate.workspaceActive ? Color.accent
                    : (Number(modelData.attention_count || 0) > 0 ? root.urgent
                      : (root.workspaceCanOpen(modelData) ? root.dim : "transparent"))
                  border.width: root.workspaceCanOpen(modelData) ? 0 : 1
                  border.color: root.dim
                }

                Column {
                  anchors.left: workspaceStateDot.right
                  anchors.leftMargin: Style.space(9)
                  anchors.right: workspaceBadge.left
                  anchors.rightMargin: Style.space(8)
                  anchors.verticalCenter: expansionTarget.verticalCenter
                  spacing: 0
                  Text {
                    width: parent.width
                    text: String(modelData.name)
                    color: workspaceTreeDelegate.workspaceActive ? Color.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: workspaceTreeDelegate.workspaceActive
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: workspaceTreeDelegate.visibleShellCount + " Shell"
                      + (workspaceTreeDelegate.visibleShellCount === 1 ? "" : "s")
                      + " · " + root.workspaceVisibleAgentCount(modelData) + " Agent"
                      + (root.workspaceVisibleAgentCount(modelData) === 1 ? "" : "s")
                      + (workspaceTreeDelegate.workspaceDefault ? " · default" : "")
                      + (Number(modelData.attention_count || 0) > 0 ? " · attention" : "")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }

                Text {
                  id: workspaceBadge
                  anchors.right: workspaceHeaderActions.left
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: expansionTarget.verticalCenter
                  text: workspaceTreeDelegate.workspaceDefault
                    && !workspaceTreeDelegate.workspaceActive ? "◆" : ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Row {
                  id: workspaceHeaderActions
                  visible: true
                  z: 2
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(5)
                  anchors.verticalCenter: expansionTarget.verticalCenter
                  width: visible ? implicitWidth : 0
                  Button {
                    id: workspaceMenuButton
                    width: Style.space(32)
                    height: Style.space(32)
                    text: "⋮"
                    tooltipText: "Workspace actions"
                    bordered: false
                    enabled: !root.workspaceMutationBusy()
                    foreground: root.foreground
                    fontSize: Style.font.body
                    horizontalPadding: Style.space(1)
                    verticalPadding: 0
                    onClicked: root.showActionMenu({ kind: "workspace",
                      workspace: workspaceTreeDelegate.modelData }, workspaceMenuButton)
                  }
                }

                MouseArea {
                  id: workspaceRowMouse
                  anchors.left: expansionTarget.right
                  anchors.right: parent.right
                  anchors.top: parent.top
                  height: workspaceTreeDelegate.rowHeight
                  hoverEnabled: true
                  enabled: root.workspaceCanOpen(workspaceTreeDelegate.modelData)
                  cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                  onEntered: {
                    root.focusSection = "workspaces"
                    root.selectedWorkspaceIndex = index
                  }
                  onClicked: root.activateWorkspaceRow(workspaceTreeDelegate.modelData)
                }

                Column {
                  id: childColumn
                  visible: workspaceTreeDelegate.workspaceExpanded
                  x: Style.space(24)
                  y: workspaceTreeDelegate.rowHeight
                  width: parent.width - x - Style.space(5)
                  spacing: Style.space(2)
                  bottomPadding: Style.space(5)

                  Text {
                    visible: workspaceTreeDelegate.treeItems.length === 0
                    width: parent.width
                    height: Style.space(34)
                    text: "No Shells or launchers"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    verticalAlignment: Text.AlignVCenter
                    leftPadding: Style.space(12)
                  }

                  Repeater {
                    id: treeItemRepeater
                    model: workspaceTreeDelegate.treeItems
                    delegate: Rectangle {
                      id: treeItemDelegate
                      required property var modelData
                      required property int index
                      readonly property bool terminalFocused:
                        WorkspaceModel.workspaceTreeItemFocused(
                          modelData, root.activeBoomuxTerminalKey)
                      width: childColumn.width
                      height: Style.space(38)
                      radius: Style.cornerRadius
                      readonly property bool cursorSelected:
                        root.focusSection === "workspace-items"
                        && workspaceTreeDelegate.index === root.selectedWorkspaceIndex
                        && index === root.selectedWorkspaceItemIndex
                      color: terminalFocused ? Util.alpha(Color.accent, 0.045)
                        : (cursorSelected ? root.keyboardCursorFill
                        : (treeItemMouse.containsMouse
                          ? Util.alpha(root.foreground, 0.035) : "transparent"))
                      opacity: treeItemMouse.enabled ? 1 : 0.48

                      Text {
                        id: treeItemGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Style.space(9)
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.kind === "launcher" ? "↗"
                          : (modelData.kind === "command" ? ">" : "○")
                        color: modelData.status === "running" ? Color.accent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                      Column {
                        anchors.left: treeItemGlyph.right
                        anchors.leftMargin: Style.space(9)
                        anchors.right: treeItemMenuButton.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                          width: parent.width
                          text: String(modelData.name)
                          color: treeItemDelegate.terminalFocused
                            ? Color.accent : root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                          font.bold: true
                          elide: Text.ElideRight
                        }
                        Text {
                          width: parent.width
                          text: String(modelData.kind) + " · " + String(modelData.status)
                            + (modelData.node_alias === "local" ? "" : " · " + modelData.node_alias)
                            + (modelData.status === "exited" ? " · open starts a new run" : "")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Math.max(8, Style.font.caption - 1)
                          elide: Text.ElideRight
                        }
                      }
                      Text {
                        id: treeItemFocusBadge
                        visible: treeItemDelegate.terminalFocused
                        anchors.right: treeItemMenuButton.left
                        anchors.rightMargin: Style.space(8)
                        anchors.verticalCenter: parent.verticalCenter
                        text: "●"
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(7, Style.font.caption - 2)
                      }
                      MouseArea {
                        id: treeItemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: root.resourceIsActionable(
                          modelData.kind === "launcher" ? modelData.launcher : modelData.shell,
                          modelData.kind === "launcher"
                            ? "remote_launcher_invocation" : "remote_pty_attachment")
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        ToolTip.visible: containsMouse && modelData.status === "exited"
                        ToolTip.text: "Opening this item starts a new run"
                        onEntered: {
                          root.focusSection = "workspace-items"
                          root.selectedWorkspaceIndex = workspaceTreeDelegate.index
                          root.selectedWorkspaceItemIndex = index
                        }
                        onClicked: root.openWorkspaceTreeItem(modelData)
                      }
                      Button {
                        id: treeItemMenuButton
                        visible: root.itemCanRename(modelData)
                        z: 1
                        anchors.right: parent.right
                        anchors.rightMargin: Style.space(5)
                        anchors.verticalCenter: parent.verticalCenter
                        width: Style.space(32)
                        height: Style.space(32)
                        text: "⋮"
                        tooltipText: "Item actions"
                        bordered: false
                        enabled: !root.workspaceMutationBusy()
                        foreground: root.foreground
                        fontSize: Style.font.caption
                        horizontalPadding: Style.space(1)
                        verticalPadding: 0
                        onClicked: root.showActionMenu(modelData, treeItemMenuButton)
                      }
                    }
                  }
                }
              }
            }
          }
        }

        Item {
          id: workspaceResizeHandle
          visible: root.cliAvailable && !root.editing
          width: parent.width
          height: Style.space(12)

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: workspaceResizeDrag.active || workspaceResizeHover.hovered
              ? Style.space(2) : 1
            color: workspaceResizeDrag.active || workspaceResizeHover.hovered
              ? Color.accent : Util.alpha(root.foreground, 0.18)
          }

          HoverHandler {
            id: workspaceResizeHover
            cursorShape: Qt.SizeVerCursor
          }

          DragHandler {
            id: workspaceResizeDrag
            target: null
            xAxis.enabled: false
            dragThreshold: 0
            property real startingHeight: root.workspaceTreeHeight
            onActiveChanged: if (active) startingHeight = root.workspaceTreeHeight
            onTranslationChanged: if (active)
              root.setWorkspaceTreeHeight(startingHeight + translation.y)
          }
        }

        Row {
          visible: root.cliAvailable && !root.editing
          width: parent.width
          spacing: Style.space(5)
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Agents"
            selected: root.activeTab === "agents"
            bordered: true
            foreground: root.foreground
            onClicked: root.selectTab("agents")
          }
          Button {
            width: (parent.width - parent.spacing) / 2
            text: "Nodes"
            selected: root.activeTab === "nodes"
            bordered: true
            foreground: root.foreground
            onClicked: root.selectTab("nodes")
          }
        }

        PanelSeparator {
          visible: root.cliAvailable && !root.editing
          foreground: root.foreground
        }

        Item {
          visible: root.cliAvailable && root.activeTab === "agents" && !root.editing
          width: parent.width
          implicitHeight: agentColumn.implicitHeight

          Column {
            id: agentColumn
            width: parent.width
            spacing: Style.space(6)
            Row {
              visible: root.webLifecycleSupported
              width: parent.width
              height: Style.space(34)
              spacing: Style.space(6)
              Text {
                width: parent.width - webActions.width - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: "Tailnet Web · " + (webStartProcess.running ? "starting"
                  : (webStopProcess.running ? "stopping" : (root.webRunning ? "live" : "off")))
                color: root.webRunning ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
              Row {
                id: webActions
                width: root.webRunning ? Style.space(142) : Style.space(86)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(5)
                Button {
                  width: root.webRunning ? Style.space(76) : Style.space(86)
                  height: Style.space(30)
                  text: webStartProcess.running ? "Starting"
                    : (root.webRunning ? "Open" : "Start Web")
                  iconText: root.webRunning ? "↗" : ""
                  tooltipText: root.webRunning ? root.webDashboardUrl
                    : "Publish the dashboard and OpenCode through Tailscale"
                  bordered: true
                  active: root.webRunning
                  focusable: true
                  enabled: root.webRunning || (root.online && !webStartProcess.running
                    && !webStopProcess.running)
                  foreground: root.foreground
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(1)
                  onClicked: root.webRunning ? root.openWeb() : root.startWeb()
                }
                Button {
                  visible: root.webRunning
                  width: Style.space(61)
                  height: Style.space(30)
                  text: webStopProcess.running ? "Stopping" : "Stop"
                  tooltipText: "Stop Web and remove only Boomux-owned Tailscale routes"
                  bordered: true
                  focusable: true
                  enabled: !webStartProcess.running && !webStopProcess.running
                  foreground: root.foreground
                  fontSize: Style.font.caption
                  horizontalPadding: Style.space(4)
                  verticalPadding: Style.space(1)
                  onClicked: root.stopWeb()
                }
              }
            }
            PanelSeparator {
              visible: root.webLifecycleSupported
              foreground: root.foreground
            }
            Row {
              width: parent.width
              PanelSectionHeader {
                width: parent.width - updatedHeader.width
                text: "AGENTS"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Text {
                id: updatedHeader
                width: Style.space(70)
                anchors.verticalCenter: parent.verticalCenter
                text: "UPDATED"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                horizontalAlignment: Text.AlignRight
              }
            }
            Text {
              visible: root.paneAgents.length === 0
              width: parent.width
              text: root.error !== "" ? root.error : "No active Boomux Agents"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(24)
              bottomPadding: Style.space(24)
            }
            ListView {
              id: agentList
              visible: root.paneAgents.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(700))
              model: root.paneAgents
              spacing: Style.space(4)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "agents" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: AgentRow {
                required property var modelData
                required property int index
                width: ListView.view.width
                agent: modelData
                selected: index === root.selectedIndex
                terminalFocused: WorkspaceModel.agentFocused(
                  modelData, root.activeBoomuxTerminalKey)
                onHovered: {
                  root.focusSection = "lower"
                  root.selectedIndex = index
                  root.selectedAgentKey = modelData.key
                }
                onActivated: root.openAgent(modelData)
                onDismissed: root.dismissAgent(modelData)
              }
            }
          }
        }

        Item {
          visible: root.cliAvailable && root.activeTab === "nodes" && !root.editing
          width: parent.width
          implicitHeight: nodeColumn.implicitHeight

          Column {
            id: nodeColumn
            width: parent.width
            spacing: Style.space(6)

            Row {
              width: parent.width
              PanelSectionHeader {
                width: parent.width - (createNodeButton.visible ? createNodeButton.width : 0)
                anchors.verticalCenter: parent.verticalCenter
                text: "NODES"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              Button {
                id: createNodeButton
                visible: root.federationAvailable
                text: "Create Node"
                iconText: "+"
                tooltipText: "Open guided Node setup"
                bordered: true
                foreground: root.foreground
                fontSize: Style.font.caption
                iconSize: Style.font.body
                horizontalPadding: Style.space(6)
                verticalPadding: Style.space(2)
                onClicked: root.createNode()
              }
            }

            Text {
              visible: root.visibleNodes.length === 0
              width: parent.width
              text: root.error !== "" ? root.error : "No remote Boomux Nodes"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              horizontalAlignment: Text.AlignHCenter
              topPadding: Style.space(24)
              bottomPadding: Style.space(24)
            }

            ListView {
              id: nodeList
              visible: root.visibleNodes.length > 0
              width: parent.width
              implicitHeight: Math.min(contentHeight, Style.space(190))
              model: root.visibleNodes
              spacing: Style.space(3)
              clip: true
              boundsBehavior: Flickable.StopAtBounds
              currentIndex: root.activeTab === "nodes" ? root.selectedIndex : -1
              ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
              delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width
                height: Style.space(58)
                radius: Style.cornerRadius
                color: index === root.selectedIndex
                  ? Style.selectedFillFor(root.foreground, Color.accent)
                  : (nodeMouse.containsMouse ? Util.alpha(root.foreground, 0.06) : "transparent")
                opacity: modelData.stale ? 0.72 : 1

                Column {
                  anchors.left: parent.left
                  anchors.right: nodeActionRow.left
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(6)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(1)
                  Text {
                    width: parent.width
                    text: String(modelData.alias)
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: index === root.selectedIndex
                    elide: Text.ElideRight
                  }
                  Text {
                    width: parent.width
                    text: root.nodeHealthLabel(modelData) + " · "
                      + root.nodeVersionIndicator(modelData)
                      + (root.nodeCanReauthenticate(modelData) ? " · action: Authenticate"
                        : (root.nodeCanUpgrade(modelData) ? " · action: Update" : ""))
                    color: modelData.health === "online" && modelData.current && !modelData.stale
                      && root.nodeVersionDirection(modelData) !== "newer" ? root.dim : root.urgent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
                MouseArea {
                  id: nodeMouse
                  anchors.left: parent.left
                  anchors.right: nodeActionRow.left
                  anchors.top: parent.top
                  anchors.bottom: parent.bottom
                  hoverEnabled: true
                  onEntered: {
                    root.focusSection = "lower"
                    root.selectedIndex = index
                    root.selectedNodeId = modelData.node_id
                  }
                  onClicked: {
                    root.selectedIndex = index
                    root.selectedNodeId = modelData.node_id
                  }
                }
                Row {
                  id: nodeActionRow
                  z: 1
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(7)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(4)
                  Button {
                    id: nodeMenuButton
                    width: Style.space(32)
                    height: Style.space(32)
                    text: "⋮"
                    tooltipText: root.nodeCanReauthenticate(modelData)
                      ? "Action required: authenticate this Node"
                      : (root.nodeCanUpgrade(modelData)
                        ? "Update available for this Node" : "Node actions")
                    bordered: true
                    enabled: !nodeShellProcess.running && !nodeUpgradeProcess.running
                      && !nodeUninstallProcess.running && !nodeReauthenticateProcess.running
                      && !actionProcess.running
                    foreground: root.nodeCanReauthenticate(modelData)
                      || root.nodeCanUpgrade(modelData) ? root.urgent : root.foreground
                    fontSize: Style.font.body
                    horizontalPadding: Style.space(4)
                    verticalPadding: Style.space(1)
                    onClicked: root.showActionMenu({ kind: "node", node: modelData },
                      nodeMenuButton)
                  }
                }
              }
            }

            BorderSurface {
              visible: root.selectedNode !== null
              width: parent.width
              implicitHeight: nodeDetailColumn.implicitHeight + Style.space(18)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.025)
              borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
              radius: Style.cornerRadius

              Column {
                id: nodeDetailColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(9)
                spacing: Style.space(5)

                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  Column {
                    width: parent.width - nodeDetailVersion.width - parent.spacing
                    spacing: 0
                    Text {
                      width: parent.width
                      text: root.selectedNode ? String(root.selectedNode.alias) : ""
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }
                    Text {
                      width: parent.width
                      text: root.selectedNode && root.selectedNode.route
                        ? String(root.selectedNode.route) : "Route unavailable"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      elide: Text.ElideMiddle
                    }
                  }
                  Text {
                    id: nodeDetailVersion
                    width: Style.space(86)
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedNode && root.selectedNode.observed_helper_version
                      ? String(root.selectedNode.observed_helper_version) : "unknown"
                    color: root.nodeVersionDirection(root.selectedNode) === "current"
                      ? Color.accent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                  }
                }
                Text {
                  width: parent.width
                  text: root.nodeRuntimeSummary(root.selectedNode)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: root.nodeWorkloadSummary(root.selectedNode)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  elide: Text.ElideRight
                }
                Text {
                  visible: root.selectedNode && (root.selectedNode.health !== "online"
                    || !root.selectedNode.current || root.selectedNode.stale)
                  width: parent.width
                  text: root.nodeHealthDetail(root.selectedNode)
                  color: root.nodeHealthColor(root.selectedNode)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
                Text {
                  visible: root.nodeNextStep(root.selectedNode) !== ""
                  width: parent.width
                  text: root.nodeNextStep(root.selectedNode)
                  color: root.nodeHealthColor(root.selectedNode)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
                Text {
                  visible: root.selectedNode && !root.selectedNode.workspace_owner_eligible
                    && root.selectedNode.workspace_owner_unavailable_reason !== ""
                  width: parent.width
                  text: root.selectedNode
                    ? String(root.selectedNode.workspace_owner_unavailable_reason || "") : ""
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  wrapMode: Text.Wrap
                }
              }
            }

          }
        }

        }
      }

      Item {
        anchors.fill: parent
        visible: root.actionMenuTarget !== null
        z: 8

        MouseArea {
          anchors.fill: parent
          onClicked: root.closeActionMenu()
        }

        Rectangle {
          id: actionMenuCard
          x: root.actionMenuX
          y: root.actionMenuY
          width: Style.space(164)
          height: actionMenuColumn.implicitHeight + Style.space(10)
          radius: Style.cornerRadius
          color: Color.background
          border.width: 1
          border.color: Util.alpha(root.foreground, 0.2)

          Column {
            id: actionMenuColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(5)
            spacing: Style.space(2)

            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "workspace"
              width: parent.width
              text: "Create Shell"
              tooltipText: root.actionMenuTarget
                ? root.workspaceCreationReason(root.actionMenuTarget.workspace) : ""
              bordered: false
              hasCursor: root.currentActionMenuAction === "shell"
              leftAlign: true
              foreground: root.foreground
              enabled: visible && root.workspaceCreationReason(root.actionMenuTarget.workspace) === ""
              onClicked: root.runActionMenuAction("shell")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("shell") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "workspace"
                && root.workspaceCanChangeDefaultPath(root.actionMenuTarget.workspace)
              width: parent.width
              text: "Shell Start Folder"
              tooltipText: "Choose where new Shells in this Workspace start"
              bordered: false
              hasCursor: root.currentActionMenuAction === "default-path"
              leftAlign: true
              foreground: root.foreground
              enabled: visible
              onClicked: root.runActionMenuAction("default-path")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("default-path") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "node"
                && !root.nodeCanReauthenticate(root.actionMenuTarget.node)
              width: parent.width
              text: "Create Shell"
              tooltipText: root.activeBoomuxWorkspaceId === ""
                ? "Show a Boomux Workspace first" : "Create a Shell on this Node"
              bordered: false
              hasCursor: root.currentActionMenuAction === "shell"
              leftAlign: true
              foreground: root.foreground
              enabled: visible && root.actionMenuTarget.node.workspace_owner_eligible
                && root.nodeIsActionable(root.actionMenuTarget.node.node_id)
                && root.activeBoomuxWorkspaceId !== "" && !nodeShellProcess.running
                && !nodeUpgradeProcess.running && !nodeUninstallProcess.running
                && !nodeReauthenticateProcess.running
              onClicked: root.runActionMenuAction("shell")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("shell") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "node"
                && root.nodeCanReauthenticate(root.actionMenuTarget.node)
              width: parent.width
              text: "Authenticate"
              bordered: false
              hasCursor: root.currentActionMenuAction === "authenticate"
              leftAlign: true
              foreground: root.urgent
              enabled: visible && !nodeReauthenticateProcess.running
                && !nodeUpgradeProcess.running && !nodeUninstallProcess.running
                && !nodeShellProcess.running
                && !actionProcess.running
              onClicked: root.runActionMenuAction("authenticate")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("authenticate") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "node"
                && root.nodeCanUpgrade(root.actionMenuTarget.node)
              width: parent.width
              text: "Update"
              bordered: false
              hasCursor: root.currentActionMenuAction === "update"
              leftAlign: true
              foreground: root.urgent
              enabled: visible && !nodeUpgradeProcess.running && !nodeShellProcess.running
                && !nodeUninstallProcess.running && !nodeReauthenticateProcess.running
                && !actionProcess.running
              onClicked: root.runActionMenuAction("update")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("update") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind !== "node"
              width: parent.width
              text: "Rename"
              bordered: false
              hasCursor: root.currentActionMenuAction === "rename"
              leftAlign: true
              foreground: root.foreground
              enabled: root.actionMenuTarget && (root.actionMenuTarget.kind === "workspace"
                ? root.workspaceCanRename(root.actionMenuTarget.workspace)
                : root.itemCanRename(root.actionMenuTarget))
              onClicked: root.runActionMenuAction("rename")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("rename") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind !== "node"
              width: parent.width
              text: root.actionMenuTarget && root.actionMenuTarget.kind === "workspace"
                ? "Remove Workspace" : (root.actionMenuTarget
                  && root.actionMenuTarget.kind === "launcher" ? "Remove Launcher" : "Close Shell")
              bordered: false
              hasCursor: root.currentActionMenuAction === "remove"
              leftAlign: true
              foreground: root.urgent
              enabled: root.actionMenuTarget && (root.actionMenuTarget.kind === "workspace"
                ? root.workspaceCanRemove(root.actionMenuTarget.workspace)
                : root.itemCanRename(root.actionMenuTarget))
              onClicked: root.runActionMenuAction("remove")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("remove") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "node"
                && root.nodeCanUninstall(root.actionMenuTarget.node)
              width: parent.width
              text: "Uninstall Boomux"
              tooltipText: "Stop remote Boomux processes, remove Boomux, then forget this Node"
              bordered: false
              hasCursor: root.currentActionMenuAction === "uninstall"
              leftAlign: true
              foreground: root.urgent
              enabled: visible && !actionProcess.running && !nodeShellProcess.running
                && !nodeUpgradeProcess.running && !nodeUninstallProcess.running
                && !nodeReauthenticateProcess.running
              onClicked: root.runActionMenuAction("uninstall")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("uninstall") }
            }
            Button {
              visible: root.actionMenuTarget && root.actionMenuTarget.kind === "node"
              width: parent.width
              text: "Forget Node"
              tooltipText: "Remove only the local registration; remote work continues"
              bordered: false
              hasCursor: root.currentActionMenuAction === "remove"
              leftAlign: true
              foreground: root.urgent
              enabled: visible && !actionProcess.running && !nodeShellProcess.running
                && !nodeUpgradeProcess.running && !nodeUninstallProcess.running
                && !nodeReauthenticateProcess.running
              onClicked: root.runActionMenuAction("remove")
              onHovered: function(hovered) { if (hovered)
                root.actionMenuIndex = root.currentActionMenuActions.indexOf("remove") }
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        visible: root.renameTarget !== null
        z: 9
        color: Util.alpha(Color.background, 0.72)

        MouseArea { anchors.fill: parent }

        Rectangle {
          anchors.centerIn: parent
          width: Math.min(parent.width - Style.space(32), Style.space(320))
          height: renameColumn.implicitHeight + Style.space(24)
          radius: Style.cornerRadius
          color: Color.background
          border.width: 1
          border.color: Util.alpha(root.foreground, 0.2)

          Column {
            id: renameColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Style.space(12)
            spacing: Style.space(8)

            Text {
              width: parent.width
              text: "Rename " + (root.renameTarget && root.renameTarget.kind === "workspace"
                ? "Workspace" : (root.renameTarget && root.renameTarget.kind === "launcher"
                  ? "Launcher" : "Shell"))
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
            }
            TextField {
              id: renameField
              width: parent.width
              foreground: root.foreground
              onTextEdited: root.renameError = ""
              onAccepted: root.confirmRename()
              Keys.onEscapePressed: root.cancelRename()
              KeyNavigation.tab: renameCancelButton
              KeyNavigation.backtab: renameConfirmButton
            }
            Text {
              visible: root.renameError !== ""
              width: parent.width
              text: root.renameError
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Row {
              width: parent.width
              spacing: Style.space(6)
              Button {
                id: renameCancelButton
                width: (parent.width - parent.spacing) / 2
                text: "Cancel"
                bordered: true
                focusable: true
                KeyNavigation.tab: renameConfirmButton
                KeyNavigation.backtab: renameField
                foreground: root.foreground
                Keys.onEscapePressed: root.cancelRename()
                onClicked: root.cancelRename()
              }
              Button {
                id: renameConfirmButton
                width: (parent.width - parent.spacing) / 2
                text: "Rename"
                bordered: true
                focusable: true
                KeyNavigation.tab: renameField
                KeyNavigation.backtab: renameCancelButton
                foreground: Color.accent
                enabled: renameField.text.trim() !== "" && !actionProcess.running
                Keys.onEscapePressed: root.cancelRename()
                onClicked: root.confirmRename()
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: removeItemDialog
        anchors.fill: parent
        opened: root.itemToRemove !== null
        z: 10
        message: root.removeItemMessage(root.itemToRemove)
        confirmText: root.removeConfirmText(root.itemToRemove)
        background: Color.background
        foreground: root.foreground
        scrim: Util.alpha(Color.background, 0.72)
        selectedBackground: Util.alpha(root.foreground, 0.08)
        selectedText: Color.accent
        fontFamily: root.fontFamily
        cornerRadius: Style.cornerRadius
        onCanceled: root.cancelRemoveItem()
        onConfirmed: root.confirmRemoveItem()
      }
      Item {
        id: removeDialogKeyHandler
        width: 1
        height: 1
        focus: root.itemToRemove !== null
        Keys.onPressed: function(event) {
          if (!root.itemToRemove) return
          if (event.key === Qt.Key_Up || event.key === Qt.Key_Down)
            removeItemDialog.selectedIndex = removeItemDialog.selectedIndex === 0 ? 1 : 0
          else removeItemDialog.handleKey(event)
          event.accepted = true
        }
      }
    }
  }

  component AgentRow: Rectangle {
    id: agentRow
    property var agent
    property bool selected: false
    property bool terminalFocused: false
    signal hovered
    signal activated
    signal dismissed
    readonly property string state: agent && agent.observation ? agent.observation.state : "unknown"
    readonly property bool needsAttention: root.agentNeedsAttention(agent)
    readonly property bool justCompleted: agent
      ? !!root.completedAgents[agent.key] || root.attentionReason(agent) === "completed" : false
    readonly property bool dismissible: agent
      ? !!root.completedAgents[agent.key] || root.attentionRevision(agent) > 0 : false
    readonly property bool actionable: agent && root.resourceIsActionable(agent,
      "remote_pty_attachment")
    readonly property bool openable: actionable && root.agentShellRetained(agent)
    readonly property bool keyboardSelected: selected && panel.keyboardMode
      && root.focusSection === "lower" && root.activeTab === "agents"

    height: Style.space(54)
    radius: Style.cornerRadius
    color: keyboardSelected ? root.keyboardCursorFill
      : (terminalFocused ? Util.alpha(Color.accent, 0.05)
      : ((selected || agentMouse.containsMouse) ? root.keyboardCursorFill : "transparent"))
    border.width: terminalFocused ? 1 : 0
    border.color: Util.alpha(Color.accent, 0.42)
    opacity: agent && agent.node_stale ? 0.66 : 1
    Text {
      id: agentGlyph
      anchors.left: parent.left
      anchors.leftMargin: Style.space(9)
      anchors.verticalCenter: parent.verticalCenter
      text: agentRow.needsAttention ? "!" : (agentRow.justCompleted ? "✓" : (agentRow.state === "working" ? "●" : "○"))
      color: agentRow.needsAttention ? root.urgent
        : (agentRow.terminalFocused ? Color.accent
        : ((agentRow.justCompleted || agentRow.state === "working") ? Color.accent : root.dim)
        )
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: agentRow.needsAttention
    }
    Column {
      anchors.left: agentGlyph.right
      anchors.leftMargin: Style.space(9)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      spacing: 0
      Row {
        width: parent.width
        Text {
          width: parent.width - updatedText.width
          text: agent ? root.agentDisplayName(agent) : "Agent"
          color: agentRow.terminalFocused ? Color.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: agentRow.terminalFocused
          elide: Text.ElideRight
        }
        Text {
          id: updatedText
          width: Style.space(62)
          text: agent ? WorkspaceModel.relativeTime(
            WorkspaceModel.agentUpdatedAt(agent), root.clockNow) : "unknown"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignRight
          elide: Text.ElideLeft
        }
      }
      Text {
        width: parent.width - (agentRow.dismissible ? Style.space(82) : 0)
        text: (agentRow.justCompleted ? "finished" : agentRow.state)
          + (agent ? " · " + String(agent.workspace_name) : "")
          + (agent && root.nodeName(agent) !== "local" ? " · " + root.nodeName(agent) : "")
          + (agentRow.needsAttention ? " · needs attention" : "")
          + (agent && !root.agentShellRetained(agent)
            ? (root.attentionRevision(agent) > 0
              ? " · shell removed · dismiss notification" : " · shell removed") : "")
          + (agent && agent.integration ? " · " + String(agent.integration) : "")
          + (agent && (agent.node_stale || !agent.node_current)
            ? " · " + root.nodeHealthLabel(root.nodeFor(agent.node_id)) : "")
        color: agentRow.needsAttention ? root.urgent : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    MouseArea {
      id: agentMouse
      anchors.fill: parent
      enabled: agentRow.openable
      hoverEnabled: true
      onEntered: agentRow.hovered()
      onClicked: agentRow.activated()
    }
    Button {
      visible: agentRow.dismissible
      z: 1
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(4)
      text: "Dismiss"
      tooltipText: "Dismiss Agent notification"
      bordered: true
      enabled: root.agentCanAcknowledge(agent)
      foreground: root.foreground
      fontSize: Style.font.caption
      horizontalPadding: Style.space(6)
      verticalPadding: Style.space(2)
      onClicked: agentRow.dismissed()
    }
  }

  component BoomuxIcon: Item {
    id: boomuxIcon
    property color color: root.foreground
    property bool lit: false
    Image {
      id: bombImage
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/bomb.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(width * 2)
      sourceSize.height: Math.round(height * 2)
      visible: false
      layer.enabled: true
    }
    MultiEffect {
      anchors.fill: bombImage
      source: bombImage
      colorization: 1.0
      colorizationColor: boomuxIcon.color
    }
    Image {
      anchors.fill: parent
      source: Qt.resolvedUrl("assets/bomb-spark.svg")
      fillMode: Image.PreserveAspectFit
      sourceSize.width: Math.round(width * 2)
      sourceSize.height: Math.round(height * 2)
      visible: boomuxIcon.lit
    }
  }
}
