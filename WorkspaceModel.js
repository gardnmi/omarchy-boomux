function resourceId(value) {
  return value && typeof value === "object" ? String(value.inner_id || "") : String(value || "")
}

function resourceNode(value, fallback) {
  return value && typeof value === "object" ? String(value.node_id || "")
    : String(fallback || "")
}

function resourceKey(nodeId, value) {
  return String(nodeId || "") + "\u001f" + resourceId(value)
}

function versionParts(value) {
  var match = String(value || "").match(/^v?(\d+)\.(\d+)\.(\d+)(?:[-+].*)?$/)
  return match ? [Number(match[1]), Number(match[2]), Number(match[3])] : null
}

function versionDirection(remote, control) {
  var remoteParts = versionParts(remote)
  var controlParts = versionParts(control)
  if (!remoteParts || !controlParts) return "unknown"
  for (var i = 0; i < 3; i++) {
    var difference = remoteParts[i] - controlParts[i]
    if (difference !== 0) return difference < 0 ? "older" : "newer"
  }
  return "current"
}

function versionIsNewer(candidate, current) {
  return versionDirection(candidate, current) === "newer"
}

function hasFeature(values, feature) {
  if (!values || typeof values.length !== "number") return false
  for (var i = 0; i < values.length; i++)
    if (String(values[i]) === feature) return true
  return false
}

function nodeCanUpgrade(node, controlVersion, cliFeatures) {
  if (!node || !node.node_id || node.local
      || versionDirection(node.observed_helper_version, controlVersion) !== "older")
    return false
  var required = ["observed_node_helper_version", "node_upgrade_coordination"]
  return required.every(function(feature) {
    return hasFeature(cliFeatures, feature) && hasFeature(node.observed_capabilities, feature)
  })
}

function guidedNodeUpgradeCommand(nodeId) {
  return ["omarchy-launch-tui", "--app-id=TUI.float",
    "boomux", "__guided-node-upgrade", String(nodeId)]
}

function nodeCanUninstall(node, cliFeatures, daemonProtocolVersion) {
  return !!node && !!node.node_id && !node.local && !!node.current && !node.stale
    && Number(daemonProtocolVersion || 0) >= 48
    && hasFeature(cliFeatures, "node_uninstall_coordination")
    && hasFeature(node.observed_capabilities, "node_uninstall_coordination")
}

function guidedNodeUninstallCommand(nodeId) {
  return ["omarchy-launch-tui", "--app-id=TUI.float",
    "boomux", "node", "uninstall", String(nodeId)]
}

function guidedLocalUpdateCommand() {
  return ["omarchy-launch-tui", "--app-id=TUI.float",
    "boomux", "update"]
}

function guidedPluginUpdateCommand() {
  return ["omarchy-launch-tui", "--app-id=TUI.float",
    "omarchy", "plugin", "update", "io.github.gardnmi.boomux", "--yes"]
}

function nodeCanReauthenticate(node, cliFeatures, daemonProtocolVersion) {
  return !!node && !!node.node_id && !node.local
    && node.health === "authentication_required"
    && Number(daemonProtocolVersion || 0) >= 38
    && Array.isArray(cliFeatures) && cliFeatures.indexOf("node_reauthentication") >= 0
}

function guidedNodeReauthenticateCommand(nodeId) {
  return ["omarchy-launch-tui", "--app-id=TUI.float",
    "boomux", "__guided-node-reauthenticate", String(nodeId)]
}

function boomuxSpecialWorkspaceId(name) {
  var match = String(name || "").match(
    /^special:boomux-([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})$/)
  return match ? match[1] : ""
}

function boomuxShellWindowKey(initialTitle, focusedKey, shells) {
  var title = String(initialTitle || "")
  var marked = title.match(/^boomux:shell:([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}):([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}) \| /)
  if (marked) return resourceKey(marked[1], marked[2])

  for (var i = 0; i < shells.length; i++) {
    var shell = shells[i]
    if (!shell || shell.key !== focusedKey) continue
    var expected = String(shell.workspace_name) + " - " + String(shell.name)
    if (!shell.node_local)
      expected = "[" + String(shell.node_alias) + "] " + expected
    return title === expected ? String(shell.key) : ""
  }
  return ""
}

function agentUpdatedAt(agent) {
  if (!agent) return 0
  var observation = agent.observation
    ? Number(agent.observation.observed_at_ms || 0) : Number(agent.observed_at_ms || 0)
  var attention = agent.attention && agent.attention.observation
    ? Number(agent.attention.observation.observed_at_ms || 0) : 0
  return Math.max(observation, attention, Number(agent.started_at_ms || 0))
}

function agentsByLastUpdated(agents) {
  return agents.slice().sort(function(left, right) {
    var difference = agentUpdatedAt(right) - agentUpdatedAt(left)
    if (difference !== 0) return difference
    var leftKey = String(left.key || left.id || "")
    var rightKey = String(right.key || right.id || "")
    return leftKey < rightKey ? -1 : (leftKey > rightKey ? 1 : 0)
  })
}

function agentFocused(agent, activeTerminalKey) {
  return !!agent && !!activeTerminalKey
    && String(agent.shell_key || "") === String(activeTerminalKey)
}

function relativeTime(timestamp, now) {
  var value = Number(timestamp || 0)
  if (value <= 0) return "unknown"
  var seconds = Math.max(0, Math.floor((Number(now || Date.now()) - value) / 1000))
  if (seconds < 60) return "now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m ago"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h ago"
  return Math.floor(seconds / 86400) + "d ago"
}

function qualifiedId(value, nodeId, field) {
  var id = resourceId(value)
  if (!id || resourceNode(value, nodeId) !== nodeId)
    throw new Error("invalid qualified " + field)
  return id
}

function qualifiedMatches(value, nodeId, innerId) {
  return resourceNode(value, nodeId) === nodeId && resourceId(value) === innerId
}

function parseEnvelope(raw, command) {
  var response = typeof raw === "string" ? JSON.parse(raw) : raw
  if (!response || response.schema !== "boomux.cli/v1" || response.command !== command
      || !response.data) throw new Error("unexpected Boomux response")
  return response.data
}

function requiredString(value, field, allowEmpty) {
  if (typeof value !== "string" || (!allowEmpty && value === ""))
    throw new Error("invalid " + field)
  return value
}

function optionalString(value, field) {
  if (value === null) return null
  return requiredString(value, field, false)
}

function requiredTimestamp(value, field) {
  if (typeof value !== "number" || !isFinite(value) || value < 0
      || Math.floor(value) !== value || value > Number.MAX_SAFE_INTEGER)
    throw new Error("invalid " + field)
  return value
}

function requiredBoundedInteger(value, field, minimum, maximum) {
  value = requiredTimestamp(value, field)
  if (value < minimum || value > maximum) throw new Error("invalid " + field)
  return value
}

function requiredEnum(value, field, values) {
  value = requiredString(value, field, false)
  if (values.indexOf(value) < 0) throw new Error("invalid " + field)
  return value
}

function optionalAbsolutePath(value, field) {
  value = optionalString(value, field)
  if (value !== null && value.indexOf("/") !== 0) throw new Error("invalid " + field)
  return value
}

function normalizeSessionObservation(source) {
  if (!source || typeof source !== "object") throw new Error("invalid session observation")
  return {
    revision: requiredBoundedInteger(source.revision, "occurrence observation revision", 1,
      Number.MAX_SAFE_INTEGER),
    state: requiredEnum(source.state, "occurrence observation state",
      ["unknown", "working", "blocked", "idle", "inactive", "done"]),
    authority: requiredEnum(source.authority, "occurrence observation authority",
      ["lifecycle_integration", "process_adapter", "terminal_heuristic", "daemon_lifecycle"]),
    evidence: requiredString(source.evidence, "occurrence observation evidence", true),
    confidence: requiredBoundedInteger(source.confidence, "occurrence observation confidence", 0, 100),
    observed_at_ms: requiredTimestamp(source.observed_at_ms, "occurrence observation timestamp")
  }
}

function normalizeSessionOccurrence(source) {
  if (!source || typeof source !== "object") throw new Error("invalid session occurrence")
  var documented = Object.prototype.hasOwnProperty.call(source, "is_current")
    || Object.prototype.hasOwnProperty.call(source, "retained_shell_name")
  var ended = source.ended_at_ms === null ? null
    : requiredTimestamp(source.ended_at_ms, "occurrence end timestamp")
  var observation = normalizeSessionObservation(source.observation)
  if (documented) {
    if (typeof source.is_current !== "boolean") throw new Error("invalid occurrence currentness")
    return {
      agent_id: requiredString(source.agent_id, "occurrence Agent ID", false),
      shell_id: requiredString(source.shell_id, "occurrence Shell ID", false),
      retained_shell_name: optionalString(source.retained_shell_name, "retained Shell name"),
      retained_shell_cwd: optionalAbsolutePath(source.retained_shell_cwd, "retained Shell cwd"),
      source_cwd: optionalAbsolutePath(source.source_cwd, "occurrence source cwd"),
      run_id: requiredString(source.run_id, "occurrence run ID", false),
      started_at_ms: requiredTimestamp(source.started_at_ms, "occurrence start timestamp"),
      ended_at_ms: ended,
      is_current: source.is_current,
      observation: observation,
      remote_raw: false
    }
  }
  requiredString(source.workspace_id, "remote occurrence Workspace ID", false)
  requiredString(source.name, "remote occurrence name", false)
  requiredString(source.integration, "remote occurrence integration", false)
  if (source.external_session_id !== null)
    requiredString(source.external_session_id, "remote occurrence external Session ID", false)
  return {
    agent_id: requiredString(source.id, "remote occurrence Agent ID", false),
    shell_id: requiredString(source.shell_id, "remote occurrence Shell ID", false),
    retained_shell_name: null,
    retained_shell_cwd: null,
    source_cwd: source.cwd === undefined ? null
      : optionalAbsolutePath(source.cwd, "remote occurrence cwd"),
    run_id: requiredString(source.run_id, "remote occurrence run ID", false),
    started_at_ms: requiredTimestamp(source.started_at_ms, "remote occurrence start timestamp"),
    ended_at_ms: ended,
    is_current: ended === null && observation.state !== "inactive" && observation.state !== "done",
    observation: observation,
    remote_raw: true
  }
}

function normalizeSessionSummary(source, nodeId, nodeAlias, local) {
  if (!source || typeof source !== "object") throw new Error("invalid Session summary")
  if (typeof source.state_is_current !== "boolean") throw new Error("invalid Session currentness")
  var occurrenceCount = requiredTimestamp(source.occurrence_count, "Session occurrence count")
  var id = requiredString(source.id, "Session ID", false)
  return {
    id: id,
    key: resourceKey(nodeId, id),
    node_id: nodeId,
    node_alias: String(nodeAlias || (local ? "local" : nodeId)),
    node_local: !!local,
    workspace_id: requiredString(source.workspace_id, "Session Workspace ID", false),
    workspace_name: requiredString(source.workspace_name, "Session Workspace name", false),
    description: requiredString(source.description, "Session description", true),
    integration: requiredString(source.integration, "Session integration", false),
    external_session_id: optionalString(source.external_session_id, "external Session ID"),
    state: requiredEnum(source.state, "Session state",
      ["unknown", "working", "blocked", "idle", "inactive", "done"]),
    state_is_current: source.state_is_current,
    started_at_ms: requiredTimestamp(source.started_at_ms, "Session start timestamp"),
    last_at_ms: requiredTimestamp(source.last_at_ms, "Session activity timestamp"),
    occurrence_count: occurrenceCount
  }
}

function normalizeSessionEnvelope(raw, command, node) {
  var data = parseEnvelope(raw, command)
  var local = !!node.local
  var nodeId = requiredString(node.node_id, "Session Node ID", false)
  var hasNode = Object.prototype.hasOwnProperty.call(data, "node_id")
  if (local ? hasNode : (!hasNode || data.node_id !== nodeId))
    throw new Error("unexpected Session Node identity")
  return data
}

function normalizeSessionList(raw, node) {
  var data = normalizeSessionEnvelope(raw, "session.list", node)
  if (!Array.isArray(data.sessions)) throw new Error("missing Sessions")
  return data.sessions.map(function(session) {
    return normalizeSessionSummary(session, String(node.node_id), String(node.alias || ""), !!node.local)
  })
}

function normalizeSessionInspect(raw, node, expectedSessionId) {
  var data = normalizeSessionEnvelope(raw, "session.inspect", node)
  var session = normalizeSessionSummary(data.session, String(node.node_id),
    String(node.alias || ""), !!node.local)
  if (session.id !== String(expectedSessionId || ""))
    throw new Error("unexpected Session identity")
  var sourceCwd = optionalAbsolutePath(data.session.source_cwd, "Session source cwd")
  if (!Array.isArray(data.session.occurrences)) throw new Error("missing Session occurrences")
  session.source_cwd = sourceCwd
  session.occurrences = data.session.occurrences.map(normalizeSessionOccurrence)
  if (session.occurrences.length !== session.occurrence_count)
    throw new Error("unexpected Session occurrence count")
  return session
}

function sessionsNewestFirst(sessions) {
  return sessions.slice().sort(function(left, right) {
    var difference = Number(right.last_at_ms) - Number(left.last_at_ms)
    if (difference !== 0) return difference
    var fields = ["node_id", "workspace_id", "id"]
    for (var i = 0; i < fields.length; i++) {
      var leftValue = String(left[fields[i]] || "")
      var rightValue = String(right[fields[i]] || "")
      if (leftValue !== rightValue) return leftValue < rightValue ? -1 : 1
    }
    return 0
  })
}

function filterSessions(sessions, query) {
  var terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean)
  if (terms.length === 0) return sessions
  return sessions.filter(function(session) {
    var text = [session.description, session.workspace_name, session.integration,
      session.state, session.state_is_current ? "current" : "historical",
      session.node_alias, session.external_session_id].map(function(value) {
        return String(value || "").toLowerCase()
      }).join(" ")
    return terms.every(function(term) { return text.indexOf(term) >= 0 })
  })
}

function sessionIdentityMatches(session, nodeId, sessionId) {
  return !!session && String(session.node_id) === String(nodeId)
    && String(session.id) === String(sessionId)
}

function sessionListCommand(node) {
  var argv = ["boomux", "session", "list", "--json"]
  if (node && !node.local) argv.push("--node", String(node.node_id))
  return argv
}

function sessionInspectCommand(session) {
  var argv = ["boomux", "session", "inspect", String(session.id), "--json"]
  if (!session.node_local) argv.push("--node", String(session.node_id))
  return argv
}

function sessionOpenCommand(session, workspaceId) {
  var argv = ["boomux", "session", "open", String(session.id)]
  if (!session.node_local) argv.push("--node", String(session.node_id))
  if (String(workspaceId || "") !== "") argv.push("--workspace", String(workspaceId))
  return argv
}

function sessionPreviewCommand(session) {
  if (!session || !session.node_local || !Array.isArray(session.occurrences)) return []
  var current = session.occurrences.find(function(occurrence) { return occurrence.is_current })
  if (!current) return []
  return ["boomux", "read", String(current.shell_id), "--lines", "40", "--json",
    "--run-id", String(current.run_id), "--after-revision", "0"]
}

function normalizeSessionPreview(raw, session) {
  var data = parseEnvelope(raw, "read")
  var current = session && Array.isArray(session.occurrences)
    ? session.occurrences.find(function(occurrence) { return occurrence.is_current }) : null
  if (!current || String(data.shell_id || "") !== String(current.shell_id)
      || String(data.run_id || "") !== String(current.run_id))
    throw new Error("unexpected Session preview identity")
  if (typeof data.output !== "string" || typeof data.status !== "string")
    throw new Error("invalid Session preview")
  return { available: true, output: data.output, status: data.status }
}

function sessionNodeEligible(node, cliFeatures) {
  if (!node || !node.node_id || !node.current || node.stale || node.health !== "online") return false
  if (node.local) return true
  if (Number(node.observed_protocol_version || 0) < 36) return false
  var required = ["typed_node_host_services", "remote_agent_session_catalog"]
  return required.every(function(feature) {
    return hasFeature(cliFeatures, feature) && hasFeature(node.observed_capabilities, feature)
  })
}

function sessionRequestCurrent(request, generation, opened, activeTab, online, node) {
  return !!request && request.generation === generation && opened && activeTab === "sessions"
    && online && !!node && node.node_id === request.nodeId
    && sessionNodeEligible(node, request.cliFeatures)
}

function sessionActionable(session, exactOpenSupported, nodeEligible) {
  return !!session && !!exactOpenSupported && !!nodeEligible && session.state !== "done"
}

function sessionHarnessLabel(integration) {
  var labels = { opencode: "OpenCode", pi: "Pi", claude: "Claude Code",
    codex: "Codex", kiro: "Kiro CLI" }
  return labels[String(integration || "")] || String(integration || "unknown")
}

function boundedSessionWarnings(warnings, limit) {
  var maximum = Math.max(1, Number(limit || 3))
  var values = warnings.slice(0, maximum).map(function(value) { return String(value) })
  if (warnings.length > maximum) values.push("+" + (warnings.length - maximum) + " more")
  return values.join(" · ")
}

function normalizeWebStatus(data) {
  if (!data || typeof data.running !== "boolean")
    throw new Error("invalid Boomux web status")
  return {
    running: data.running,
    port: Number(data.port || 3737),
    tailscale: data.running && data.tailscale === true,
    dashboard_url: data.running ? String(data.dashboard_url || "") : "",
    opencode_url: data.running ? String(data.opencode_url || "") : ""
  }
}

function availableAgentHosts(data) {
  if (!data || !Array.isArray(data.integrations)) throw new Error("missing integrations")
  var hosts = []
  for (var i = 0; i < data.integrations.length; i++) {
    var integration = data.integrations[i]
    if (!integration || typeof integration.name !== "string"
        || typeof integration.display_name !== "string"
        || !integration.host || !integration.asset)
      throw new Error("invalid integration status")
    if (integration.host.state !== "available" || integration.asset.state !== "current") continue
    var executable = String(integration.host.executable || "")
    if (executable === "") continue
    hosts.push({
      name: String(integration.name),
      label: String(integration.display_name),
      command: [executable]
    })
  }
  return hosts
}

function shellOwner(owner) {
  if (typeof owner === "string") return owner
  return owner && owner.kind === "schedule" ? "schedule" : "user"
}

function agentHasPrivateOwner(agent, shells) {
  if (!agent || !agent.shell_id) return false
  for (var i = 0; i < shells.length; i++) {
    var shell = shells[i]
    if (shell && shell.node_id === agent.node_id && shell.id === agent.shell_id)
      return shellOwner(shell.owner) === "schedule"
  }
  return false
}

function userWorkspaceResources(shells, agents) {
  return {
    shells: shells.filter(function(shell) {
      return shellOwner(shell.owner) !== "schedule"
    }),
    agents: agents.filter(function(agent) {
      return !agentHasPrivateOwner(agent, shells)
    })
  }
}

function userShellCount(shells, nodeId, workspaceId) {
  return shells.filter(function(shell) {
    return shell && shell.node_id === nodeId && shell.workspace_id === workspaceId
      && shellOwner(shell.owner) !== "schedule"
  }).length
}

function userAttentionCount(agents) {
  return agents.filter(function(agent) { return !!agent.attention }).length
}

function withoutLegacySchedules(value) {
  var copy = Object.assign({}, value)
  delete copy.schedules
  return copy
}

function shellStatus(status) {
  if (typeof status === "string") return status
  return status && status.exited !== undefined ? "exited" : "unknown"
}

function normalizeAgent(source, node, workspaceName) {
  var id = qualifiedId(source.id, node.node_id, "Agent ID")
  var workspaceId = qualifiedId(source.workspace_id, node.node_id, "Agent Workspace ID")
  var shellId = qualifiedId(source.shell_id, node.node_id, "Agent Shell ID")
  var runId = qualifiedId(source.run_id, node.node_id, "Agent run ID")
  var observation = source.observation || {
    revision: Number(source.observation_revision || 0),
    state: String(source.state || "unknown"),
    authority: "daemon_lifecycle",
    evidence: node.local ? "" : "cached reduced observation",
    confidence: 0,
    observed_at_ms: Number(source.observed_at_ms || 0)
  }
  var attention = source.attention || null
  if (attention && !attention.observation) attention = {
    reason: attention.reason,
    observation: {
      revision: Number(attention.observation_revision || 0),
      observed_at_ms: Number(attention.observed_at_ms || 0)
    }
  }
  return Object.assign({}, source, {
    id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
    node_alias: node.alias, node_local: node.local, node_current: node.current,
    node_stale: node.stale, workspace_id: workspaceId,
    workspace_key: resourceKey(node.node_id, workspaceId),
    workspace_name: String(source.workspace_name || workspaceName || "unknown"),
    shell_id: shellId, shell_key: resourceKey(node.node_id, shellId), run_id: runId,
    run_key: resourceKey(node.node_id, runId), observation: observation, attention: attention
  })
}

function normalizeShell(source, node, workspaceId, workspaceName, workspaceKey) {
  var id = qualifiedId(source.id, node.node_id, "Shell ID")
  if (!qualifiedMatches(source.workspace_id || workspaceId, node.node_id, workspaceId))
    throw new Error("invalid qualified Shell Workspace ID")
  var run = source.run || (source.run_id ? { id: source.run_id } : null)
  if (run) {
    var runId = qualifiedId(run.id, node.node_id, "Shell run ID")
    run = Object.assign({}, run, { id: runId, key: resourceKey(node.node_id, runId) })
  }
  return Object.assign({}, source, {
    id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
    node_alias: node.alias, node_local: node.local, node_current: node.current,
    node_stale: node.stale, workspace_id: workspaceId, workspace_key: workspaceKey,
    workspace_name: workspaceName, owner: shellOwner(source.owner),
    status: shellStatus(source.status), run: run
  })
}

function normalizeLauncher(source, node, workspaceId, workspaceName, workspaceKey) {
  var id = qualifiedId(source.id, node.node_id, "launcher ID")
  if (!qualifiedMatches(source.workspace_id || workspaceId, node.node_id, workspaceId))
    throw new Error("invalid qualified launcher Workspace ID")
  return Object.assign({}, source, {
    id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
    node_alias: node.alias, node_local: node.local, node_current: node.current,
    node_stale: node.stale, workspace_id: workspaceId, workspace_key: workspaceKey,
    workspace_name: workspaceName
  })
}

function ownerKey(nodeId, workspaceId) {
  return JSON.stringify([String(nodeId || ""), resourceId(workspaceId)])
}

function globalKey(workspaceId) {
  return "global\u001f" + String(workspaceId || "")
}

function externalKey(nodeId, workspaceId) {
  return "external\u001f" + String(nodeId || "") + "\u001f" + resourceId(workspaceId)
}

function nodeFor(nodes, nodeId) {
  for (var i = 0; i < nodes.length; i++)
    if (nodes[i].node_id === nodeId) return nodes[i]
  return null
}

function projectedResourcesByWorkspace(resources, nodeId) {
  if (!Array.isArray(resources)) throw new Error("invalid projected resources")
  var result = {}
  for (var i = 0; i < resources.length; i++) {
    var resource = resources[i]
    if (resourceNode(resource.workspace_id, nodeId) !== nodeId) continue
    var key = resourceKey(nodeId, resource.workspace_id)
    if (!result[key]) result[key] = []
    result[key].push(resource)
  }
  return result
}

function unavailableNode(nodeId) {
  return {
    node_id: String(nodeId),
    alias: "unregistered:" + String(nodeId).substring(0, 8),
    local: false,
    health: "unobserved",
    current: false,
    stale: true,
    observed_capabilities: [],
    workspace_owner_eligible: false,
    workspace_owner_unavailable_reason: "Node is not registered"
  }
}

function workspaceResources(owner, globalId, globalName, workspaceKey, placementState) {
  var fields = ["shells", "launchers", "agents"]
  var result = {}
  for (var f = 0; f < fields.length; f++) {
    var field = fields[f]
    result[field] = (owner[field] || []).map(function(resource) {
      return Object.assign({}, resource, {
        owner_workspace_id: owner.id,
        global_workspace_id: globalId || "",
        workspace_key: workspaceKey,
        workspace_name: globalName,
        placement_state: placementState
      })
    })
  }
  return result
}

function groupedWorkspace(global, ownersByKey, nodesById, claimed) {
  var key = globalKey(global.id)
  var placements = []
  var shells = [], launchers = [], agents = []
  var attentionCount = 0
  for (var p = 0; p < (global.placements || []).length; p++) {
    var source = global.placements[p]
    var sourceNodeId = typeof source.node_id === "string" ? source.node_id : null
    var node = sourceNodeId !== null ? nodesById[resourceKey("node", sourceNodeId)] : null
    node = node || unavailableNode(source.node_id)
    var ownerIdentity = ownerKey(source.node_id, source.workspace_id)
    var owner = sourceNodeId !== null ? (ownersByKey[ownerIdentity] || null) : null
    if (owner) claimed[ownerIdentity] = true
    var resources = workspaceResources(owner || { id: resourceId(source.workspace_id) },
      global.id, global.name, key, String(source.state || "unavailable"))
    shells = shells.concat(resources.shells)
    launchers = launchers.concat(resources.launchers)
    agents = agents.concat(resources.agents)
    attentionCount += userAttentionCount(resources.agents)
    placements.push(Object.assign({}, source, {
      workspace_id: resourceId(source.workspace_id),
      node_id: String(source.node_id),
      node_alias: node.alias,
      node_health: node.health,
      node_current: node.current,
      node_stale: node.stale,
      available: String(source.state) === "active" && node.current && !node.stale
    }))
  }
  return Object.assign({}, global, {
    key: key,
    coordination: "global",
    is_global: true,
    is_external: false,
    placements: placements,
    shells: shells,
    launchers: launchers,
    agents: agents,
    shell_count: shells.length,
    launcher_count: launchers.length,
    attention_count: attentionCount
  })
}

function externalWorkspace(external, ownersByKey, nodesById, claimed) {
  var nodeId = String(external.identity.node_id)
  var workspaceId = resourceId(external.identity)
  var node = nodesById[resourceKey("node", nodeId)] || unavailableNode(nodeId)
  var ownerIdentity = ownerKey(nodeId, workspaceId)
  var owner = ownersByKey[ownerIdentity] || null
  if (owner) claimed[ownerIdentity] = true
  var key = externalKey(nodeId, workspaceId)
  var resources = workspaceResources(owner || { id: workspaceId }, "", external.name, key,
    external.available ? "active" : "unavailable")
  var workspace = Object.assign({}, owner || {}, external, resources, {
    id: workspaceId,
    key: key,
    coordination: "external",
    is_global: false,
    is_external: true,
    node_id: nodeId,
    node_alias: node.alias,
    node_local: node.local,
    node_health: node.health,
    node_current: node.current,
    node_stale: node.stale,
    available: !!external.available && node.current && !node.stale,
    shell_count: resources.shells.length,
    launcher_count: resources.launchers.length,
    attention_count: userAttentionCount(resources.agents)
  })
  delete workspace.schedules
  return workspace
}

function snapshotSupportsGlobalWorkspaces(nodes) {
  var local = null
  for (var i = 0; i < nodes.length; i++) if (nodes[i].local) local = nodes[i]
  if (!local) return false
  return local.observed_protocol_version >= 38
    || local.observed_capabilities.indexOf("global_workspaces") >= 0
}

function groupSnapshot(data, ownerWorkspaces, nodes) {
  if (!snapshotSupportsGlobalWorkspaces(nodes)) return ownerWorkspaces.map(function(owner) {
    return withoutLegacySchedules(Object.assign({}, owner, {
      coordination: "legacy",
      is_global: false,
      is_external: false
    }))
  })

  var claimed = {}
  var result = []
  var ownersByKey = {}, nodesById = {}
  for (var n = 0; n < nodes.length; n++) {
    var nodeIdentity = resourceKey("node", nodes[n].node_id)
    if (!nodesById[nodeIdentity]) nodesById[nodeIdentity] = nodes[n]
  }
  for (var o = 0; o < ownerWorkspaces.length; o++) {
    var ownerIdentity = ownerKey(ownerWorkspaces[o].node_id, ownerWorkspaces[o].id)
    if (!ownersByKey[ownerIdentity]) ownersByKey[ownerIdentity] = ownerWorkspaces[o]
  }
  for (var g = 0; g < data.workspaces.length; g++)
    result.push(groupedWorkspace(data.workspaces[g], ownersByKey, nodesById, claimed))
  for (var e = 0; e < data.external_workspaces.length; e++)
    result.push(externalWorkspace(data.external_workspaces[e], ownersByKey, nodesById, claimed))

  // Keep unexpected unlinked projections visible and structurally distinct.
  for (var w = 0; w < ownerWorkspaces.length; w++) {
    var owner = ownerWorkspaces[w]
    if (claimed[ownerKey(owner.node_id, owner.id)]) continue
    result.push(externalWorkspace({
      identity: { node_id: owner.node_id, inner_id: owner.id },
      revision: Number(owner.revision || 0),
      name: owner.name,
      default_cwd: owner.default_cwd,
      available: !!owner.node_current && !owner.node_stale
    }, ownersByKey, nodesById, claimed))
  }
  return result
}

function normalizeNodeSnapshot(data) {
  if (!data || !Array.isArray(data.nodes)) throw new Error("missing Nodes")
  var nodes = [], ownerWorkspaces = []
  for (var n = 0; n < data.nodes.length; n++) {
    var rawNode = data.nodes[n]
    if (!rawNode || typeof rawNode.node_id !== "string" || typeof rawNode.alias !== "string")
      throw new Error("invalid Node")
    var node = {
      node_id: rawNode.node_id,
      alias: rawNode.alias,
      local: !!rawNode.local,
      route: String(rawNode.route || ""),
      registration_revision: Number(rawNode.registration_revision || 0),
      health: String(rawNode.health || "unobserved"),
      current: !!rawNode.current,
      stale: !!rawNode.stale,
      observed_at_ms: Number(rawNode.observed_at_ms || 0),
      observed_protocol_version: Number(rawNode.observed_protocol_version || 0),
      observed_helper_version: String(rawNode.observed_helper_version || ""),
      observed_capabilities: Array.isArray(rawNode.observed_capabilities)
        ? rawNode.observed_capabilities : [],
      workspace_owner_eligible: !!rawNode.workspace_owner_eligible,
      workspace_owner_unavailable_reason:
        String(rawNode.workspace_owner_unavailable_reason || ""),
      workspace_count: 0,
      shell_count: 0,
      agent_count: 0,
      launcher_count: 0
    }
    nodes.push(node)
    var projection = node.local ? rawNode.local_snapshot : rawNode.remote_projection
    if (!projection) continue
    var projectedWorkspaces = projection.workspaces || []
    var projectedShells = node.local ? [] : (projection.shells || [])
    var projectedLaunchers = node.local ? [] : (projection.launchers || [])
    var projectedAgents = node.local ? [] : (projection.agents || [])
    var projectedShellsByWorkspace = node.local ? {} : projectedResourcesByWorkspace(
      projectedShells, node.node_id)
    var projectedLaunchersByWorkspace = node.local ? {} : projectedResourcesByWorkspace(
      projectedLaunchers, node.node_id)
    var projectedAgentsByWorkspace = node.local ? {} : projectedResourcesByWorkspace(
      projectedAgents, node.node_id)
    for (var w = 0; w < projectedWorkspaces.length; w++) {
      var rawWorkspace = projectedWorkspaces[w]
      var workspaceId = qualifiedId(rawWorkspace.id, node.node_id, "Workspace ID")
      var workspaceKey = resourceKey(node.node_id, workspaceId)
      var workspace = Object.assign({}, rawWorkspace, {
        id: workspaceId, key: workspaceKey, node_id: node.node_id,
        node_alias: node.alias, node_local: node.local, node_current: node.current,
        node_stale: node.stale, node_health: node.health,
        shells: [], launchers: [], agents: []
      })
      delete workspace.schedules
      if (node.local) {
        workspace.shells = (rawWorkspace.shells || []).map(function(item) {
          return normalizeShell(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.launchers = (rawWorkspace.launchers || []).map(function(item) {
          return normalizeLauncher(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.agents = (rawWorkspace.agents || []).map(function(item) {
          return normalizeAgent(item, node, rawWorkspace.name)
        })
      } else {
        workspace.shells = (projectedShellsByWorkspace[workspaceKey] || []).map(function(item) {
          return normalizeShell(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.launchers = (projectedLaunchersByWorkspace[workspaceKey] || []).map(function(item) {
          return normalizeLauncher(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.agents = (projectedAgentsByWorkspace[workspaceKey] || []).map(function(item) {
          return normalizeAgent(item, node, rawWorkspace.name)
        })
      }
      var userResources = userWorkspaceResources(workspace.shells, workspace.agents)
      workspace.shells = userResources.shells
      workspace.agents = userResources.agents
      workspace.shell_count = workspace.shells.length
      workspace.launcher_count = workspace.launchers.length
      workspace.attention_count = userAttentionCount(workspace.agents)
      node.workspace_count++
      node.shell_count += workspace.shells.length
      node.agent_count += workspace.agents.length
      node.launcher_count += workspace.launchers.length
      ownerWorkspaces.push(workspace)
    }
  }
  var workspaces = groupSnapshot(data, ownerWorkspaces, nodes)
  var shells = [], agents = []
  for (var g = 0; g < workspaces.length; g++) {
    shells = shells.concat(workspaces[g].shells || [])
    agents = agents.concat(workspaces[g].agents || [])
  }
  return {
    nodes: nodes,
    workspaces: workspaces,
    shells: shells,
    agents: agents,
    focused_terminal: normalizeFocusedTerminal(data.focused_terminal)
  }
}

function normalizeFocusedTerminal(source) {
  if (source === undefined || source === null) return null
  if (!source.shell || typeof source.shell.node_id !== "string"
      || typeof source.shell.inner_id !== "string"
      || !Number.isFinite(Number(source.revision)) || Number(source.revision) <= 0)
    throw new Error("invalid focused terminal")
  return {
    revision: Number(source.revision),
    node_id: String(source.shell.node_id),
    shell_id: String(source.shell.inner_id)
  }
}

function normalizeWorkspaceDetail(source, workspace, node) {
  if (!source || !workspace || !node || resourceId(source.id) !== workspace.id)
    throw new Error("invalid Workspace detail")
  var workspaceKey = workspace.key || resourceKey(node.node_id, workspace.id)
  var placementState = workspace.placement_state || "active"
  function ownership(resource) {
    return Object.assign({}, resource, {
      owner_workspace_id: workspace.id,
      placement_state: placementState
    })
  }
  var detail = Object.assign({}, source, workspace, {
    id: workspace.id,
    key: workspaceKey,
    node_id: node.node_id,
    node_alias: node.alias,
    node_local: node.local,
    node_current: node.current,
    node_stale: node.stale
  })
  delete detail.schedules
  detail.shells = (source.shells || []).map(function(shell) {
    return ownership(normalizeShell(shell, node, workspace.id, detail.name, workspaceKey))
  })
  detail.launchers = (source.launchers || []).map(function(launcher) {
    return ownership(normalizeLauncher(launcher, node, workspace.id, detail.name, workspaceKey))
  })
  detail.agents = (source.agents || []).map(function(agent) {
    return ownership(normalizeAgent(agent, node, detail.name))
  })
  var userResources = userWorkspaceResources(detail.shells, detail.agents)
  detail.shells = userResources.shells
  detail.agents = userResources.agents
  detail.shell_count = detail.shells.length
  detail.attention_count = userAttentionCount(detail.agents)
  return detail
}

function workspaceOpenCommand(workspace, showDesktop, presentationOnly) {
  if (presentationOnly && workspace.is_global)
    return ["boomux", "desktop", "show", String(workspace.id)]
  var command = ["boomux", "workspace", "open", String(workspace.id)]
  if (workspace.is_external && workspace.node_id)
    command.push("--node", String(workspace.node_id))
  else if (!workspace.is_global && workspace.node_id && !workspace.node_local)
    command.push("--node", String(workspace.node_id))
  if (showDesktop && workspace.is_global) command.push("--show")
  return command
}

function workspaceTreeItems(workspace) {
  if (!workspace) return []
  var items = []
  var shells = workspace.shells || []
  var agents = workspace.agents || []
  for (var s = 0; s < shells.length; s++) {
    var shell = shells[s]
    if (!shell || shellOwner(shell.owner) === "schedule") continue
    var activeAgent = null
    for (var a = 0; a < agents.length; a++) {
      var candidate = agents[a]
      var state = candidate && candidate.observation
        ? String(candidate.observation.state || "unknown") : "unknown"
      if (agentMatchesShell(candidate, shell) && candidate.ended_at_ms == null
          && state !== "inactive" && state !== "done") {
        activeAgent = candidate
        break
      }
    }
    items.push({
      key: String(shell.key || resourceKey(shell.node_id, shell.id)),
      kind: activeAgent ? "agent"
        : (shell.command && shell.command.length > 0 ? "command" : "shell"),
      name: String(shell.name || "unnamed"),
      status: shellStatus(shell.status),
      detail: shell.command && shell.command.length > 0
        ? shell.command.join(" ") : String(shell.cwd || ""),
      node_id: String(shell.node_id || ""),
      node_alias: String(shell.node_alias || "local"),
      placement_state: String(shell.placement_state || "active"),
      workspace: workspace,
      shell: shell,
      launcher: null
    })
  }
  var launchers = workspace.launchers || []
  for (var l = 0; l < launchers.length; l++) {
    var launcher = launchers[l]
    if (!launcher) continue
    items.push({
      key: String(launcher.key || resourceKey(launcher.node_id, launcher.id)),
      id: String(launcher.id || ""),
      kind: "launcher",
      name: String(launcher.name || "unnamed"),
      status: "on open",
      detail: launcher.command ? launcher.command.join(" ") : "",
      node_id: String(launcher.node_id || ""),
      node_alias: String(launcher.node_alias || "local"),
      node_local: !!launcher.node_local,
      placement_state: String(launcher.placement_state || "active"),
      workspace: workspace,
      shell: null,
      launcher: launcher
    })
  }
  return items
}

function workspaceTreeModelSignature(workspaces) {
  return JSON.stringify((workspaces || []).map(function(workspace) {
    return {
      row: [workspace.key, workspace.id, workspace.name, !!workspace.is_global,
        !!workspace.is_external, !!workspace.closing, !!workspace.available,
        workspace.node_id, workspace.node_current, workspace.node_stale,
        workspace.default_cwd, Number(workspace.attention_count || 0),
        Number(workspace.shell_count || 0)],
      placements: (workspace.placements || []).map(function(placement) {
        return [placement.node_id, placement.workspace_id, placement.state,
          placement.default_cwd, !!placement.available,
          !!placement.node_current, !!placement.node_stale]
      }),
      items: workspaceTreeItems(workspace).map(function(item) {
        var resource = item.kind === "launcher" ? item.launcher : item.shell
        return [item.key, item.kind, item.name, item.status, item.detail,
          item.node_id, item.node_alias, item.placement_state,
          resource ? resource.id : "", resource ? resource.owner : "",
          resource ? !!resource.node_current : false,
          resource ? !!resource.node_stale : false]
      })
    }
  }))
}

function workspaceTreeItemFocused(item, activeTerminalKey) {
  return !!item && item.kind !== "launcher" && !!item.shell
    && String(activeTerminalKey || "") !== ""
    && String(item.key || "") === String(activeTerminalKey)
}

function workspaceCloseCommand(workspace) {
  return ["boomux", "workspace", "close", String(workspace.id)]
}

function qualifiedCommand(prefix, resourceIdValue, nodeId, local) {
  var command = prefix.concat([String(resourceIdValue)])
  if (!local) command.push("--node", String(nodeId))
  return command
}

function shellOpenCommand(shell, workspace, local) {
  var command = qualifiedCommand(["boomux", "open"], shell.id, shell.node_id, local)
  command.push("--takeover")
  if (workspace && workspace.is_global)
    command.push("--workspace", String(workspace.id))
  return command
}

function eligibleNodes(nodes) {
  return nodes.filter(function(node) { return !!node.workspace_owner_eligible })
}

function defaultCreationNodeId(nodes) {
  var eligible = eligibleNodes(nodes)
  for (var i = 0; i < eligible.length; i++)
    if (eligible[i].local) return String(eligible[i].node_id)
  return eligible.length === 1 ? String(eligible[0].node_id) : ""
}

function localWorkspaceCreationNode(nodes) {
  var matches = (nodes || []).filter(function(node) {
    return !!node && !!node.local && !!node.workspace_owner_eligible
      && !!node.current && !node.stale && node.health === "online"
  })
  return matches.length === 1 ? matches[0] : null
}

function atomicWorkspaceCreateCommand(nodeId, cwd, name) {
  var command = ["boomux", "workspace", "create"]
  if (name) command.push(String(name))
  return command.concat(["--node", String(nodeId), "--cwd", String(cwd), "--json"])
}

function workspaceDaemonStartCommand() {
  return ["boomux", "workspace", "list", "--json"]
}

function absolutePath(value) {
  return typeof value === "string" && value.indexOf("/") === 0
}

function atomicWorkspaceCreateIdentity(data, nodeId) {
  if (!data || !data.workspace || !data.placement || !data.shell)
    throw new Error("missing atomic Workspace creation fields")
  var workspace = data.workspace
  var placement = data.placement
  var shell = data.shell
  var strings = [workspace.id, workspace.name, placement.node_id,
    placement.owner_workspace_id, placement.default_cwd,
    shell.id, shell.name, shell.node_id, shell.cwd]
  if (strings.some(function(value) { return typeof value !== "string" || value === "" })
      || !Number.isFinite(Number(workspace.revision)) || Number(workspace.revision) <= 0
      || placement.node_id !== nodeId || shell.node_id !== nodeId
      || !absolutePath(placement.default_cwd) || !absolutePath(shell.cwd)
      || placement.default_cwd !== shell.cwd)
    throw new Error("invalid atomic Workspace creation identity")
  return {
    workspaceId: workspace.id,
    workspaceName: workspace.name,
    workspaceRevision: Number(workspace.revision),
    nodeId: placement.node_id,
    ownerWorkspaceId: placement.owner_workspace_id,
    defaultCwd: placement.default_cwd,
    shellId: shell.id,
    shellName: shell.name
  }
}

function resolveAtomicWorkspaceCreation(identity, workspaces) {
  if (!identity) return null
  var matches = (workspaces || []).filter(function(workspace) {
    return workspace && workspace.is_global && workspace.id === identity.workspaceId
      && Number(workspace.revision || 0) >= identity.workspaceRevision
  })
  if (matches.length !== 1) return null
  var workspace = matches[0]
  if (workspace.name !== undefined && workspace.name !== identity.workspaceName) return null
  var placements = (workspace.placements || []).filter(function(placement) {
    return placement.node_id === identity.nodeId
      && placement.workspace_id === identity.ownerWorkspaceId
      && placement.default_cwd === identity.defaultCwd
      && String(placement.state) === "active"
  })
  var shells = (workspace.shells || []).filter(function(shell) {
    return shell.node_id === identity.nodeId && shell.id === identity.shellId
      && shell.cwd === identity.defaultCwd
      && (shell.name === undefined || shell.name === identity.shellName)
  })
  return placements.length === 1 && shells.length === 1
    ? { workspace: workspace, placement: placements[0], shell: shells[0] } : null
}

function atomicWorkspaceCreationConflicts(identity, workspaces) {
  if (!identity) return false
  return (workspaces || []).some(function(workspace) {
    return workspace && workspace.is_global && workspace.id === identity.workspaceId
      && Number(workspace.revision || 0) >= identity.workspaceRevision
  }) && !resolveAtomicWorkspaceCreation(identity, workspaces)
}

function localActiveWorkspacePlacement(workspace, nodes) {
  if (!workspace || !workspace.is_global || workspace.closing) return null
  var matches = (workspace.placements || []).filter(function(placement) {
    var node = nodeFor(nodes || [], placement.node_id)
    return String(placement.state) === "active" && !!placement.available
      && !!node && !!node.local && !!node.current && !node.stale
      && node.health === "online"
  })
  return matches.length === 1 ? matches[0] : null
}

function workspaceDefaultCwdCommand(workspaceId, nodeId, cwd) {
  return ["boomux", "workspace", "set-default-cwd", String(workspaceId),
    "--node", String(nodeId), "--cwd", String(cwd), "--json"]
}

function workspaceDefaultCwdIdentity(data, expected) {
  var fields = ["workspace_id", "node_id", "owner_workspace_id", "default_cwd", "result"]
  if (!data || fields.some(function(field) {
    return typeof data[field] !== "string" || data[field] === ""
  }) || !Number.isFinite(Number(data.global_revision)) || Number(data.global_revision) <= 0
      || !Number.isFinite(Number(data.owner_revision)) || Number(data.owner_revision) <= 0
      || !absolutePath(data.default_cwd)
      || (data.result !== "updated" && data.result !== "unchanged")
      || data.workspace_id !== expected.workspaceId || data.node_id !== expected.nodeId
      || data.owner_workspace_id !== expected.ownerWorkspaceId
      )
    throw new Error("invalid Workspace default directory identity")
  return {
    workspaceId: data.workspace_id,
    nodeId: data.node_id,
    ownerWorkspaceId: data.owner_workspace_id,
    defaultCwd: data.default_cwd,
    globalRevision: Number(data.global_revision),
    ownerRevision: Number(data.owner_revision),
    result: data.result
  }
}

function resolveWorkspaceDefaultCwd(identity, workspaces) {
  if (!identity) return null
  var matches = (workspaces || []).filter(function(workspace) {
    return workspace && workspace.is_global && workspace.id === identity.workspaceId
      && Number(workspace.revision || 0) >= identity.globalRevision
  })
  if (matches.length !== 1) return null
  var placements = (matches[0].placements || []).filter(function(placement) {
    return placement.node_id === identity.nodeId
      && placement.workspace_id === identity.ownerWorkspaceId
      && placement.default_cwd === identity.defaultCwd
      && Number(placement.owner_revision || 0) >= identity.ownerRevision
      && String(placement.state) === "active"
  })
  return placements.length === 1
    ? { workspace: matches[0], placement: placements[0] } : null
}

function workspaceDefaultCwdConflicts(identity, workspaces) {
  if (!identity) return false
  return (workspaces || []).some(function(workspace) {
    return workspace && workspace.is_global && workspace.id === identity.workspaceId
      && Number(workspace.revision || 0) >= identity.globalRevision
  }) && !resolveWorkspaceDefaultCwd(identity, workspaces)
}

function workspaceCreationBlockReason(workspace, eligibleNodeCount) {
  if (!workspace) return "No Workspace is selected"
  if (workspace.is_global && workspace.closing)
    return "This Workspace is closing; retry or finish close before creating resources"
  if (workspace.is_global && eligibleNodeCount === 0)
    return "No Node is currently eligible for Workspace placement"
  if (workspace.is_external)
    return "Adopt or link this external Workspace before creating resources"
  if (!workspace.is_global && !workspace.node_local)
    return "Creation is unavailable for this owner Workspace"
  return ""
}

function suggestionIdentity(workspaceKey, nodeId, ownerWorkspaceId) {
  return {
    workspaceKey: String(workspaceKey),
    nodeId: String(nodeId),
    ownerWorkspaceId: String(ownerWorkspaceId),
    key: String(workspaceKey) + "\u001f" + String(nodeId) + "\u001f"
      + String(ownerWorkspaceId)
  }
}

function suggestionResponseMatches(data, identity, nodeLocal, requireNodeIdentity) {
  if (!data || !identity || resourceId(data.workspace_id) !== identity.ownerWorkspaceId)
    return false
  if (requireNodeIdentity) return String(data.node_id || "") === identity.nodeId
  if (!nodeLocal && String(data.node_id || "") !== identity.nodeId) return false
  return nodeLocal || !data.node_id || String(data.node_id) === identity.nodeId
}

function agentMatchesShell(agent, shell) {
  if (!agent || !shell || agent.node_id !== shell.node_id || agent.shell_id !== shell.id)
    return false
  var runId = shell.run ? shell.run.id : shell.run_id
  return !!runId && agent.run_id === runId
}

function retainedShellForAgent(agent, shells) {
  if (!agent || !agent.shell_id) return null
  for (var i = 0; i < shells.length; i++)
    if (shells[i].node_id === agent.node_id && shells[i].id === agent.shell_id) return shells[i]
  return null
}

function agentOpenTarget(agent, shells, nodeActionable) {
  var shell = retainedShellForAgent(agent, shells)
  return resourceActionable(agent, nodeActionable)
    && resourceActionable(shell, nodeActionable) ? shell : null
}

function projectDiscoveryIdentity(nodeId) {
  return String(nodeId || "")
}

function projectDiscoveryResponseCurrent(requestedNodeId, activeNodeId, selectedNodeId) {
  return !!activeNodeId && requestedNodeId === activeNodeId && activeNodeId === selectedNodeId
}

function projectDiscoveryCommand(node) {
  var command = ["boomux", "project", "list", "--json"]
  if (node && !node.local) command.push("--node", String(node.node_id))
  return command
}

function shellCreateCommand(workspace, name, cwd, nodeId, command) {
  var argv = ["boomux", "shell", "create", String(workspace.id), "--name", String(name)]
  if (cwd) argv.push("--cwd", String(cwd))
  if (workspace.is_global || workspace.is_external || !workspace.node_local)
    argv.push("--node", String(nodeId))
  if (command && command.length > 0) argv = argv.concat(["--"], command)
  return argv
}

function resolvePendingShell(pending, workspaceModels) {
  if (!pending) return null
  var matches = []
  for (var w = 0; w < workspaceModels.length; w++) {
    var workspace = workspaceModels[w]
    if (!workspace || workspace.key !== pending.workspaceKey) continue
    for (var s = 0; s < (workspace.shells || []).length; s++) {
      var shell = workspace.shells[s]
      if (shell.node_id === pending.nodeId && String(shell.name) === pending.name)
        matches.push(shell)
    }
  }
  if (matches.length !== 1) return null
  var shell = matches[0]
  return {
    shell: shell,
    identity: {
      workspaceKey: pending.workspaceKey,
      nodeId: shell.node_id,
      shellId: shell.id,
      runId: shell.run ? String(shell.run.id || "") : String(shell.run_id || "")
    }
  }
}

function consumePendingShell(pending, workspaceModels) {
  var resolved = resolvePendingShell(pending, workspaceModels)
  return resolved ? { pending: null, resolved: resolved }
    : { pending: pending, resolved: null }
}

function resourceActionable(resource, nodeActionable) {
  return !!resource && resource.placement_state !== "unavailable"
    && resource.placement_state !== "close_pending" && !!nodeActionable
}

function acknowledgementIdentity(agent, revision) {
  return {
    agentKey: resourceKey(agent.node_id, agent.id),
    nodeId: String(agent.node_id),
    agentId: String(agent.id),
    revision: Number(revision)
  }
}

function acknowledgementResponseMatches(data, identity) {
  return !!data && !!data.agent && resourceId(data.agent.id) === identity.agentId
}

if (typeof module !== "undefined") module.exports = {
  versionIsNewer: versionIsNewer,
  versionDirection: versionDirection,
  nodeCanUpgrade: nodeCanUpgrade,
  guidedNodeUpgradeCommand: guidedNodeUpgradeCommand,
  nodeCanUninstall: nodeCanUninstall,
  guidedNodeUninstallCommand: guidedNodeUninstallCommand,
  guidedLocalUpdateCommand: guidedLocalUpdateCommand,
  guidedPluginUpdateCommand: guidedPluginUpdateCommand,
  nodeCanReauthenticate: nodeCanReauthenticate,
  guidedNodeReauthenticateCommand: guidedNodeReauthenticateCommand,
  agentUpdatedAt: agentUpdatedAt,
  agentsByLastUpdated: agentsByLastUpdated,
  agentFocused: agentFocused,
  relativeTime: relativeTime,
  resourceId: resourceId,
  resourceNode: resourceNode,
  resourceKey: resourceKey,
  boomuxSpecialWorkspaceId: boomuxSpecialWorkspaceId,
  boomuxShellWindowKey: boomuxShellWindowKey,
  qualifiedMatches: qualifiedMatches,
  parseEnvelope: parseEnvelope,
  normalizeSessionList: normalizeSessionList,
  normalizeSessionInspect: normalizeSessionInspect,
  normalizeSessionOccurrence: normalizeSessionOccurrence,
  sessionsNewestFirst: sessionsNewestFirst,
  filterSessions: filterSessions,
  sessionIdentityMatches: sessionIdentityMatches,
  sessionListCommand: sessionListCommand,
  sessionInspectCommand: sessionInspectCommand,
  sessionOpenCommand: sessionOpenCommand,
  sessionPreviewCommand: sessionPreviewCommand,
  normalizeSessionPreview: normalizeSessionPreview,
  sessionNodeEligible: sessionNodeEligible,
  sessionRequestCurrent: sessionRequestCurrent,
  sessionActionable: sessionActionable,
  sessionHarnessLabel: sessionHarnessLabel,
  boundedSessionWarnings: boundedSessionWarnings,
  normalizeWebStatus: normalizeWebStatus,
  availableAgentHosts: availableAgentHosts,
  normalizeAgent: normalizeAgent,
  normalizeShell: normalizeShell,
  normalizeLauncher: normalizeLauncher,
  agentHasPrivateOwner: agentHasPrivateOwner,
  userShellCount: userShellCount,
  normalizeFocusedTerminal: normalizeFocusedTerminal,
  normalizeNodeSnapshot: normalizeNodeSnapshot,
  normalizeWorkspaceDetail: normalizeWorkspaceDetail,
  snapshotSupportsGlobalWorkspaces: snapshotSupportsGlobalWorkspaces,
  ownerKey: ownerKey,
  globalKey: globalKey,
  externalKey: externalKey,
  groupSnapshot: groupSnapshot,
  workspaceOpenCommand: workspaceOpenCommand,
  workspaceTreeItems: workspaceTreeItems,
  workspaceTreeModelSignature: workspaceTreeModelSignature,
  workspaceTreeItemFocused: workspaceTreeItemFocused,
  workspaceCloseCommand: workspaceCloseCommand,
  qualifiedCommand: qualifiedCommand,
  shellOpenCommand: shellOpenCommand,
  eligibleNodes: eligibleNodes,
  defaultCreationNodeId: defaultCreationNodeId,
  localWorkspaceCreationNode: localWorkspaceCreationNode,
  atomicWorkspaceCreateCommand: atomicWorkspaceCreateCommand,
  workspaceDaemonStartCommand: workspaceDaemonStartCommand,
  atomicWorkspaceCreateIdentity: atomicWorkspaceCreateIdentity,
  resolveAtomicWorkspaceCreation: resolveAtomicWorkspaceCreation,
  atomicWorkspaceCreationConflicts: atomicWorkspaceCreationConflicts,
  localActiveWorkspacePlacement: localActiveWorkspacePlacement,
  workspaceDefaultCwdCommand: workspaceDefaultCwdCommand,
  workspaceDefaultCwdIdentity: workspaceDefaultCwdIdentity,
  resolveWorkspaceDefaultCwd: resolveWorkspaceDefaultCwd,
  workspaceDefaultCwdConflicts: workspaceDefaultCwdConflicts,
  workspaceCreationBlockReason: workspaceCreationBlockReason,
  suggestionIdentity: suggestionIdentity,
  suggestionResponseMatches: suggestionResponseMatches,
  agentMatchesShell: agentMatchesShell,
  retainedShellForAgent: retainedShellForAgent,
  agentOpenTarget: agentOpenTarget,
  projectDiscoveryIdentity: projectDiscoveryIdentity,
  projectDiscoveryResponseCurrent: projectDiscoveryResponseCurrent,
  projectDiscoveryCommand: projectDiscoveryCommand,
  shellCreateCommand: shellCreateCommand,
  resolvePendingShell: resolvePendingShell,
  consumePendingShell: consumePendingShell,
  resourceActionable: resourceActionable,
  acknowledgementIdentity: acknowledgementIdentity,
  acknowledgementResponseMatches: acknowledgementResponseMatches
}
