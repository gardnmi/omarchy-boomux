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

function shellOwner(owner) {
  if (typeof owner === "string") return owner
  return owner && owner.kind === "schedule" ? "schedule" : "user"
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

function normalizeSchedule(source, node, workspaceName) {
  var id = qualifiedId(source.id, node.node_id, "Schedule ID")
  var workspaceId = qualifiedId(source.workspace_id, node.node_id, "Schedule Workspace ID")
  var trigger = source.trigger || {}
  return Object.assign({}, source, {
    id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
    node_alias: node.alias, node_local: node.local, node_current: node.current,
    node_stale: node.stale, workspace_id: workspaceId,
    workspace_key: resourceKey(node.node_id, workspaceId),
    workspace_name: String(source.workspace_name || workspaceName || "unknown"),
    cron: String(source.cron || trigger.cron || ""),
    timezone: String(source.timezone || trigger.timezone || ""),
    session_mode: source.session_mode
      || (source.session && source.session.continue ? "continue" : "fresh"),
    cwd: source.cwd || (node.local ? "" : "remote path available on owner")
  })
}

function optionalQualifiedId(value, nodeId, field) {
  return value === null || value === undefined ? "" : qualifiedId(value, nodeId, field)
}

function normalizeExecution(source, node) {
  var id = qualifiedId(source.id, node.node_id, "execution ID")
  var scheduleId = qualifiedId(source.schedule_id, node.node_id, "execution Schedule ID")
  return Object.assign({}, source, {
    id: id, key: resourceKey(node.node_id, id), node_id: node.node_id,
    node_alias: node.alias, node_local: node.local, node_current: node.current,
    node_stale: node.stale, schedule_id: scheduleId,
    schedule_key: resourceKey(node.node_id, scheduleId),
    workspace_id: qualifiedId(source.workspace_id, node.node_id, "execution Workspace ID"),
    shell_id: optionalQualifiedId(source.shell_id, node.node_id, "execution Shell ID"),
    run_id: optionalQualifiedId(source.run_id, node.node_id, "execution run ID"),
    agent_id: optionalQualifiedId(source.agent_id, node.node_id, "execution Agent ID")
  })
}

function ownerKey(nodeId, workspaceId) {
  return "owner\u001f" + String(nodeId || "") + "\u001f" + resourceId(workspaceId)
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
    workspace_owner_unavailable_reason: "Node is not registered",
    scheduler: { state: "offline", active_executions: 0, max_concurrent: 0 }
  }
}

function workspaceResources(owner, globalId, globalName, workspaceKey, placementState) {
  var fields = ["shells", "launchers", "agents", "schedules"]
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

function groupedWorkspace(global, ownerWorkspaces, nodes, claimed) {
  var key = globalKey(global.id)
  var placements = []
  var shells = [], launchers = [], agents = [], schedules = []
  var attentionCount = 0
  for (var p = 0; p < (global.placements || []).length; p++) {
    var source = global.placements[p]
    var node = nodeFor(nodes, source.node_id) || unavailableNode(source.node_id)
    var owner = null
    for (var w = 0; w < ownerWorkspaces.length; w++) {
      if (ownerWorkspaces[w].node_id === source.node_id
          && ownerWorkspaces[w].id === resourceId(source.workspace_id)) {
        owner = ownerWorkspaces[w]
        claimed[ownerKey(source.node_id, source.workspace_id)] = true
        break
      }
    }
    var resources = workspaceResources(owner || { id: resourceId(source.workspace_id) },
      global.id, global.name, key, String(source.state || "unavailable"))
    shells = shells.concat(resources.shells)
    launchers = launchers.concat(resources.launchers)
    agents = agents.concat(resources.agents)
    schedules = schedules.concat(resources.schedules)
    attentionCount += owner ? Number(owner.attention_count || 0) : 0
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
    schedules: schedules,
    shell_count: shells.length,
    launcher_count: launchers.length,
    schedule_count: schedules.length,
    attention_count: attentionCount
  })
}

function externalWorkspace(external, ownerWorkspaces, nodes, claimed) {
  var nodeId = String(external.identity.node_id)
  var workspaceId = resourceId(external.identity)
  var node = nodeFor(nodes, nodeId) || unavailableNode(nodeId)
  var owner = null
  for (var w = 0; w < ownerWorkspaces.length; w++) {
    if (ownerWorkspaces[w].node_id === nodeId && ownerWorkspaces[w].id === workspaceId) {
      owner = ownerWorkspaces[w]
      claimed[ownerKey(nodeId, workspaceId)] = true
      break
    }
  }
  var key = externalKey(nodeId, workspaceId)
  var resources = workspaceResources(owner || { id: workspaceId }, "", external.name, key,
    external.available ? "active" : "unavailable")
  return Object.assign({}, owner || {}, external, resources, {
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
    schedule_count: resources.schedules.length
  })
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
    return Object.assign({}, owner, {
      coordination: "legacy",
      is_global: false,
      is_external: false
    })
  })

  var claimed = {}
  var result = []
  for (var g = 0; g < data.workspaces.length; g++)
    result.push(groupedWorkspace(data.workspaces[g], ownerWorkspaces, nodes, claimed))
  for (var e = 0; e < data.external_workspaces.length; e++)
    result.push(externalWorkspace(data.external_workspaces[e], ownerWorkspaces, nodes, claimed))

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
    }, ownerWorkspaces, nodes, claimed))
  }
  return result
}

function normalizeNodeSnapshot(data) {
  if (!data || !Array.isArray(data.nodes)) throw new Error("missing Nodes")
  var nodes = [], ownerWorkspaces = [], executions = []
  for (var n = 0; n < data.nodes.length; n++) {
    var rawNode = data.nodes[n]
    if (!rawNode || typeof rawNode.node_id !== "string" || typeof rawNode.alias !== "string")
      throw new Error("invalid Node")
    var node = {
      node_id: rawNode.node_id,
      alias: rawNode.alias,
      local: !!rawNode.local,
      health: String(rawNode.health || "unobserved"),
      current: !!rawNode.current,
      stale: !!rawNode.stale,
      observed_at_ms: Number(rawNode.observed_at_ms || 0),
      observed_protocol_version: Number(rawNode.observed_protocol_version || 0),
      observed_capabilities: Array.isArray(rawNode.observed_capabilities)
        ? rawNode.observed_capabilities : [],
      workspace_owner_eligible: !!rawNode.workspace_owner_eligible,
      workspace_owner_unavailable_reason:
        String(rawNode.workspace_owner_unavailable_reason || ""),
      scheduler: rawNode.scheduler
        || { state: "offline", active_executions: 0, max_concurrent: 0 }
    }
    nodes.push(node)
    var projection = node.local ? rawNode.local_snapshot : rawNode.remote_projection
    if (!projection) continue
    var projectedWorkspaces = projection.workspaces || []
    var projectedShells = node.local ? [] : (projection.shells || [])
    var projectedLaunchers = node.local ? [] : (projection.launchers || [])
    var projectedAgents = node.local ? [] : (projection.agents || [])
    var projectedSchedules = node.local ? [] : (projection.schedules || [])
    for (var w = 0; w < projectedWorkspaces.length; w++) {
      var rawWorkspace = projectedWorkspaces[w]
      var workspaceId = qualifiedId(rawWorkspace.id, node.node_id, "Workspace ID")
      var workspaceKey = resourceKey(node.node_id, workspaceId)
      var workspace = Object.assign({}, rawWorkspace, {
        id: workspaceId, key: workspaceKey, node_id: node.node_id,
        node_alias: node.alias, node_local: node.local, node_current: node.current,
        node_stale: node.stale, node_health: node.health,
        shells: [], launchers: [], agents: [], schedules: []
      })
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
        workspace.schedules = (rawWorkspace.schedules || []).map(function(item) {
          return normalizeSchedule(item, node, rawWorkspace.name)
        })
      } else {
        workspace.shells = projectedShells.filter(function(item) {
          return qualifiedMatches(item.workspace_id, node.node_id, workspaceId)
        }).map(function(item) {
          return normalizeShell(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.launchers = projectedLaunchers.filter(function(item) {
          return qualifiedMatches(item.workspace_id, node.node_id, workspaceId)
        }).map(function(item) {
          return normalizeLauncher(item, node, workspaceId, rawWorkspace.name, workspaceKey)
        })
        workspace.agents = projectedAgents.filter(function(item) {
          return qualifiedMatches(item.workspace_id, node.node_id, workspaceId)
        }).map(function(item) {
          return normalizeAgent(item, node, rawWorkspace.name)
        })
        workspace.schedules = projectedSchedules.filter(function(item) {
          return qualifiedMatches(item.workspace_id, node.node_id, workspaceId)
        }).map(function(item) {
          return normalizeSchedule(item, node, rawWorkspace.name)
        })
      }
      workspace.shell_count = workspace.shells.length
      workspace.launcher_count = workspace.launchers.length
      workspace.schedule_count = workspace.schedules.length
      ownerWorkspaces.push(workspace)
    }
    var projectedExecutions = node.local ? [] : (projection.executions || [])
    for (var e = 0; e < projectedExecutions.length; e++)
      executions.push(normalizeExecution(projectedExecutions[e], node))
  }
  var workspaces = groupSnapshot(data, ownerWorkspaces, nodes)
  var shells = [], agents = [], schedules = []
  for (var g = 0; g < workspaces.length; g++) {
    shells = shells.concat(workspaces[g].shells || [])
    agents = agents.concat(workspaces[g].agents || [])
    schedules = schedules.concat(workspaces[g].schedules || [])
  }
  return {
    nodes: nodes,
    workspaces: workspaces,
    shells: shells,
    agents: agents,
    schedules: schedules,
    executions: executions
  }
}

function mergeSnapshotExecutions(current, snapshot, retainedScheduleKey) {
  if (!retainedScheduleKey) return snapshot
  return snapshot.filter(function(execution) {
    return execution.schedule_key !== retainedScheduleKey
  }).concat(current.filter(function(execution) {
    return execution.schedule_key === retainedScheduleKey
  }))
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
  detail.shells = (source.shells || []).map(function(shell) {
    return ownership(normalizeShell(shell, node, workspace.id, detail.name, workspaceKey))
  })
  detail.launchers = (source.launchers || []).map(function(launcher) {
    return ownership(normalizeLauncher(launcher, node, workspace.id, detail.name, workspaceKey))
  })
  detail.agents = (source.agents || []).map(function(agent) {
    return ownership(normalizeAgent(agent, node, detail.name))
  })
  detail.schedules = (source.schedules || []).map(function(schedule) {
    return ownership(normalizeSchedule(schedule, node, detail.name))
  })
  return detail
}

function workspaceOpenCommand(workspace) {
  var command = ["boomux", "workspace", "open", String(workspace.id)]
  if (workspace.is_external && workspace.node_id)
    command.push("--node", String(workspace.node_id))
  else if (!workspace.is_global && workspace.node_id && !workspace.node_local)
    command.push("--node", String(workspace.node_id))
  return command
}

function workspaceCloseCommand(workspace) {
  return ["boomux", "workspace", "close", String(workspace.id)]
}

function qualifiedCommand(prefix, resourceIdValue, nodeId, local) {
  var command = prefix.concat([String(resourceIdValue)])
  if (!local) command.push("--node", String(nodeId))
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

function creationNodeArgs(nodes, selectedNodeId) {
  var eligible = eligibleNodes(nodes)
  for (var i = 0; i < eligible.length; i++)
    if (eligible[i].node_id === selectedNodeId) return ["--node", String(selectedNodeId)]
  return null
}

function workspaceCreateCommand(name, cwd, nodeArgs, atomicGlobal) {
  if (!atomicGlobal) {
    var legacy = ["boomux", "workspace", "create", String(name)]
    if (cwd) legacy.push("--cwd", String(cwd))
    return legacy
  }
  var command = ["boomux", "workspace", "create-project", String(name),
    "--cwd", String(cwd)]
  return command.concat(nodeArgs || []).concat(["--json"])
}

function parseProjectCreationResponse(raw, expectedNodeId) {
  var data = parseEnvelope(raw, "workspace.create-project")
  if (!data.workspace || typeof data.workspace.id !== "string" || !data.shell
      || typeof data.shell.id !== "string" || typeof data.shell.workspace_id !== "string"
      || data.node_id !== expectedNodeId) throw new Error("invalid project Workspace response")
  var placement = (data.workspace.placements || []).filter(function(candidate) {
    return candidate.node_id === data.node_id
      && candidate.workspace_id === data.shell.workspace_id
  })
  if (placement.length !== 1) throw new Error("project Shell placement does not match")
  return data
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
  resourceId: resourceId,
  resourceNode: resourceNode,
  resourceKey: resourceKey,
  qualifiedMatches: qualifiedMatches,
  parseEnvelope: parseEnvelope,
  normalizeAgent: normalizeAgent,
  normalizeShell: normalizeShell,
  normalizeLauncher: normalizeLauncher,
  normalizeSchedule: normalizeSchedule,
  normalizeExecution: normalizeExecution,
  normalizeNodeSnapshot: normalizeNodeSnapshot,
  mergeSnapshotExecutions: mergeSnapshotExecutions,
  normalizeWorkspaceDetail: normalizeWorkspaceDetail,
  snapshotSupportsGlobalWorkspaces: snapshotSupportsGlobalWorkspaces,
  ownerKey: ownerKey,
  globalKey: globalKey,
  externalKey: externalKey,
  groupSnapshot: groupSnapshot,
  workspaceOpenCommand: workspaceOpenCommand,
  workspaceCloseCommand: workspaceCloseCommand,
  qualifiedCommand: qualifiedCommand,
  eligibleNodes: eligibleNodes,
  defaultCreationNodeId: defaultCreationNodeId,
  creationNodeArgs: creationNodeArgs,
  workspaceCreateCommand: workspaceCreateCommand,
  parseProjectCreationResponse: parseProjectCreationResponse,
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
