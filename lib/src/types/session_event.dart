/// Session events — discriminated union using Dart 3 sealed classes.
///
/// Derived from the canonical upstream `session-events.schema.json`.
/// All event payloads live in a `data` sub-object in the wire format.
///
/// Uses sealed classes for exhaustive pattern matching:
/// ```dart
/// session.on((event) {
///   switch (event) {
///     case AssistantMessageEvent(:final content):
///       print('Assistant: $content');
///     case ToolExecutionStartEvent(:final toolName):
///       print('Tool: $toolName');
///     case SessionIdleEvent():
///       print('Done');
///   }
/// });
/// ```
library;

/// Base class for all session events.
sealed class SessionEvent {
  const SessionEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    this.parentId,
    this.ephemeral = false,
  });

  /// Unique event ID.
  final String id;

  /// ISO-8601 timestamp.
  final String timestamp;

  /// Event type discriminator.
  final String type;

  /// Parent event ID (for nested events like tool execution under a turn).
  final String? parentId;

  /// Whether this event is ephemeral (not persisted in session history).
  final bool ephemeral;

  /// Deserialize from JSON, dispatching on the 'type' field.
  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return _factories[type]?.call(json) ?? UnknownEvent._fromJson(json, type);
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Extracts the `data` sub-object from event JSON.
/// Falls back to `json` itself for backward compatibility with flat formats.
Map<String, dynamic> _data(Map<String, dynamic> json) {
  final d = json['data'];
  return d is Map<String, dynamic> ? d : json;
}

T _required<T>(Map<String, dynamic> data, String key, String eventType) {
  final value = data[key];
  if (value is T) return value;
  throw FormatException(
    'Invalid or missing required field "$key" for event type "$eventType"',
  );
}

// ── Session Lifecycle Events ────────────────────────────────────────────────

final class SessionStartEvent extends SessionEvent {
  const SessionStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.sessionId,
    required this.version,
    required this.producer,
    required this.copilotVersion,
    required this.startTime,
    this.selectedModel,
    this.context,
  }) : super(type: 'session.start');

  final String sessionId;
  final int version;
  final String producer;
  final String copilotVersion;
  final String startTime;
  final String? selectedModel;
  final Map<String, dynamic>? context;

  factory SessionStartEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      sessionId: _required<String>(d, 'sessionId', 'session.start'),
      version: _required<int>(d, 'version', 'session.start'),
      producer: _required<String>(d, 'producer', 'session.start'),
      copilotVersion: _required<String>(d, 'copilotVersion', 'session.start'),
      startTime: _required<String>(d, 'startTime', 'session.start'),
      selectedModel: d['selectedModel'] as String?,
      context: d['context'] as Map<String, dynamic>?,
    );
  }
}

final class SessionResumeEvent extends SessionEvent {
  const SessionResumeEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.resumeTime,
    required this.eventCount,
    this.context,
  }) : super(type: 'session.resume');

  final String resumeTime;
  final int eventCount;
  final Map<String, dynamic>? context;

  factory SessionResumeEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionResumeEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      resumeTime: _required<String>(d, 'resumeTime', 'session.resume'),
      eventCount: _required<int>(d, 'eventCount', 'session.resume'),
      context: d['context'] as Map<String, dynamic>?,
    );
  }
}

final class SessionErrorEvent extends SessionEvent {
  const SessionErrorEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.errorType,
    required this.message,
    this.stack,
    this.statusCode,
    this.providerCallId,
  }) : super(type: 'session.error');

  final String errorType;
  final String message;
  final String? stack;
  final int? statusCode;
  final String? providerCallId;

  factory SessionErrorEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionErrorEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      errorType: _required<String>(d, 'errorType', 'session.error'),
      message: _required<String>(d, 'message', 'session.error'),
      stack: d['stack'] as String?,
      statusCode: d['statusCode'] as int?,
      providerCallId: d['providerCallId'] as String?,
    );
  }
}

final class SessionIdleEvent extends SessionEvent {
  const SessionIdleEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
  }) : super(type: 'session.idle');

  factory SessionIdleEvent._fromJson(Map<String, dynamic> json) {
    return SessionIdleEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
    );
  }
}

final class SessionTitleChangedEvent extends SessionEvent {
  const SessionTitleChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.title,
  }) : super(type: 'session.title_changed');

  final String title;

  factory SessionTitleChangedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionTitleChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      title: d['title'] as String? ?? '',
    );
  }
}

final class SessionInfoEvent extends SessionEvent {
  const SessionInfoEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.infoType,
    required this.message,
  }) : super(type: 'session.info');

  final String infoType;
  final String message;

  factory SessionInfoEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionInfoEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      infoType: d['infoType'] as String? ?? '',
      message: d['message'] as String? ?? '',
    );
  }
}

final class SessionWarningEvent extends SessionEvent {
  const SessionWarningEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.warningType,
    required this.message,
  }) : super(type: 'session.warning');

  final String warningType;
  final String message;

  factory SessionWarningEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionWarningEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      warningType: d['warningType'] as String? ?? '',
      message: d['message'] as String? ?? '',
    );
  }
}

final class SessionModelChangeEvent extends SessionEvent {
  const SessionModelChangeEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.previousModel,
    required this.newModel,
  }) : super(type: 'session.model_change');

  final String? previousModel;
  final String newModel;

  factory SessionModelChangeEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionModelChangeEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      previousModel: d['previousModel'] as String?,
      newModel: d['newModel'] as String? ?? '',
    );
  }
}

final class SessionModeChangedEvent extends SessionEvent {
  const SessionModeChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.previousMode,
    required this.newMode,
  }) : super(type: 'session.mode_changed');

  final String previousMode;
  final String newMode;

  factory SessionModeChangedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionModeChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      previousMode: d['previousMode'] as String? ?? '',
      newMode: d['newMode'] as String? ?? '',
    );
  }
}

final class SessionPlanChangedEvent extends SessionEvent {
  const SessionPlanChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.operation,
  }) : super(type: 'session.plan_changed');

  /// One of "create", "update", "delete".
  final String operation;

  factory SessionPlanChangedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionPlanChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      operation: d['operation'] as String? ?? '',
    );
  }
}

final class SessionWorkspaceFileChangedEvent extends SessionEvent {
  const SessionWorkspaceFileChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.path,
    required this.operation,
  }) : super(type: 'session.workspace_file_changed');

  /// Relative path within the workspace files directory.
  final String path;

  /// One of "create", "update".
  final String operation;

  factory SessionWorkspaceFileChangedEvent._fromJson(
      Map<String, dynamic> json) {
    final d = _data(json);
    return SessionWorkspaceFileChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      path: d['path'] as String? ?? '',
      operation: d['operation'] as String? ?? '',
    );
  }
}

final class SessionHandoffEvent extends SessionEvent {
  const SessionHandoffEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.handoffTime,
    required this.sourceType,
    this.repository,
    this.context,
    this.summary,
    this.remoteSessionId,
  }) : super(type: 'session.handoff');

  final String handoffTime;

  /// One of "remote", "local".
  final String sourceType;
  final Map<String, dynamic>? repository;
  final String? context;
  final String? summary;
  final String? remoteSessionId;

  factory SessionHandoffEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionHandoffEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      handoffTime: d['handoffTime'] as String? ?? '',
      sourceType: d['sourceType'] as String? ?? '',
      repository: d['repository'] as Map<String, dynamic>?,
      context: d['context'] as String?,
      summary: d['summary'] as String?,
      remoteSessionId: d['remoteSessionId'] as String?,
    );
  }
}

final class SessionTruncationEvent extends SessionEvent {
  const SessionTruncationEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.tokenLimit,
    required this.preTruncationTokensInMessages,
    required this.preTruncationMessagesLength,
    required this.postTruncationTokensInMessages,
    required this.postTruncationMessagesLength,
    required this.tokensRemovedDuringTruncation,
    required this.messagesRemovedDuringTruncation,
    required this.performedBy,
  }) : super(type: 'session.truncation');

  final int tokenLimit;
  final int preTruncationTokensInMessages;
  final int preTruncationMessagesLength;
  final int postTruncationTokensInMessages;
  final int postTruncationMessagesLength;
  final int tokensRemovedDuringTruncation;
  final int messagesRemovedDuringTruncation;
  final String performedBy;

  factory SessionTruncationEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionTruncationEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      tokenLimit: d['tokenLimit'] as int? ?? 0,
      preTruncationTokensInMessages:
          d['preTruncationTokensInMessages'] as int? ?? 0,
      preTruncationMessagesLength:
          d['preTruncationMessagesLength'] as int? ?? 0,
      postTruncationTokensInMessages:
          d['postTruncationTokensInMessages'] as int? ?? 0,
      postTruncationMessagesLength:
          d['postTruncationMessagesLength'] as int? ?? 0,
      tokensRemovedDuringTruncation:
          d['tokensRemovedDuringTruncation'] as int? ?? 0,
      messagesRemovedDuringTruncation:
          d['messagesRemovedDuringTruncation'] as int? ?? 0,
      performedBy: d['performedBy'] as String? ?? '',
    );
  }
}

final class SessionSnapshotRewindEvent extends SessionEvent {
  const SessionSnapshotRewindEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.upToEventId,
    required this.eventsRemoved,
  }) : super(type: 'session.snapshot_rewind');

  final String upToEventId;
  final int eventsRemoved;

  factory SessionSnapshotRewindEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionSnapshotRewindEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      upToEventId: d['upToEventId'] as String? ?? '',
      eventsRemoved: d['eventsRemoved'] as int? ?? 0,
    );
  }
}

final class SessionShutdownEvent extends SessionEvent {
  const SessionShutdownEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.shutdownType,
    this.errorReason,
    required this.totalPremiumRequests,
    required this.totalApiDurationMs,
    required this.sessionStartTime,
    this.codeChanges,
    this.modelMetrics,
    this.currentModel,
  }) : super(type: 'session.shutdown');

  /// One of "routine", "error".
  final String shutdownType;
  final String? errorReason;
  final int totalPremiumRequests;
  final int totalApiDurationMs;
  final int sessionStartTime;
  final Map<String, dynamic>? codeChanges;
  final Map<String, dynamic>? modelMetrics;
  final String? currentModel;

  factory SessionShutdownEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionShutdownEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      shutdownType: d['shutdownType'] as String? ?? 'routine',
      errorReason: d['errorReason'] as String?,
      totalPremiumRequests: d['totalPremiumRequests'] as int? ?? 0,
      totalApiDurationMs: d['totalApiDurationMs'] as int? ?? 0,
      sessionStartTime: d['sessionStartTime'] as int? ?? 0,
      codeChanges: d['codeChanges'] as Map<String, dynamic>?,
      modelMetrics: d['modelMetrics'] as Map<String, dynamic>?,
      currentModel: d['currentModel'] as String?,
    );
  }
}

final class SessionContextChangedEvent extends SessionEvent {
  const SessionContextChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.cwd,
    this.gitRoot,
    this.repository,
    this.branch,
  }) : super(type: 'session.context_changed');

  final String cwd;
  final String? gitRoot;
  final String? repository;
  final String? branch;

  factory SessionContextChangedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionContextChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      cwd: d['cwd'] as String? ?? '',
      gitRoot: d['gitRoot'] as String?,
      repository: d['repository'] as String?,
      branch: d['branch'] as String?,
    );
  }
}

final class SessionUsageInfoEvent extends SessionEvent {
  const SessionUsageInfoEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.tokenLimit,
    required this.currentTokens,
    required this.messagesLength,
  }) : super(type: 'session.usage_info');

  final int tokenLimit;
  final int currentTokens;
  final int messagesLength;

  factory SessionUsageInfoEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionUsageInfoEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      tokenLimit: d['tokenLimit'] as int? ?? 0,
      currentTokens: d['currentTokens'] as int? ?? 0,
      messagesLength: d['messagesLength'] as int? ?? 0,
    );
  }
}

final class SessionCompactionStartEvent extends SessionEvent {
  const SessionCompactionStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
  }) : super(type: 'session.compaction_start');

  factory SessionCompactionStartEvent._fromJson(Map<String, dynamic> json) {
    return SessionCompactionStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
    );
  }
}

final class SessionCompactionCompleteEvent extends SessionEvent {
  const SessionCompactionCompleteEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.success,
    this.error,
    this.preCompactionTokens,
    this.postCompactionTokens,
    this.preCompactionMessagesLength,
    this.messagesRemoved,
    this.tokensRemoved,
    this.summaryContent,
    this.checkpointNumber,
    this.checkpointPath,
    this.compactionTokensUsed,
    this.requestId,
  }) : super(type: 'session.compaction_complete');

  final bool success;
  final String? error;
  final int? preCompactionTokens;
  final int? postCompactionTokens;
  final int? preCompactionMessagesLength;
  final int? messagesRemoved;
  final int? tokensRemoved;
  final String? summaryContent;
  final int? checkpointNumber;
  final String? checkpointPath;
  final Map<String, dynamic>? compactionTokensUsed;
  final String? requestId;

  factory SessionCompactionCompleteEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionCompactionCompleteEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      success: d['success'] as bool? ?? false,
      error: d['error'] as String?,
      preCompactionTokens: d['preCompactionTokens'] as int?,
      postCompactionTokens: d['postCompactionTokens'] as int?,
      preCompactionMessagesLength: d['preCompactionMessagesLength'] as int?,
      messagesRemoved: d['messagesRemoved'] as int?,
      tokensRemoved: d['tokensRemoved'] as int?,
      summaryContent: d['summaryContent'] as String?,
      checkpointNumber: d['checkpointNumber'] as int?,
      checkpointPath: d['checkpointPath'] as String?,
      compactionTokensUsed: d['compactionTokensUsed'] as Map<String, dynamic>?,
      requestId: d['requestId'] as String?,
    );
  }
}

final class SessionTaskCompleteEvent extends SessionEvent {
  const SessionTaskCompleteEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.summary,
  }) : super(type: 'session.task_complete');

  final String? summary;

  factory SessionTaskCompleteEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SessionTaskCompleteEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      summary: d['summary'] as String?,
    );
  }
}

// ── Message Events ──────────────────────────────────────────────────────────

final class UserMessageEvent extends SessionEvent {
  const UserMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
    this.transformedContent,
    this.attachments,
    this.source,
    this.agentMode,
  }) : super(type: 'user.message');

  final String content;
  final String? transformedContent;
  final List<dynamic>? attachments;
  final String? source;

  /// One of "interactive", "plan", "autopilot", "shell".
  final String? agentMode;

  factory UserMessageEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return UserMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: d['content'] as String? ?? '',
      transformedContent: d['transformedContent'] as String?,
      attachments: d['attachments'] as List<dynamic>?,
      source: d['source'] as String?,
      agentMode: d['agentMode'] as String?,
    );
  }
}

final class PendingMessagesModifiedEvent extends SessionEvent {
  const PendingMessagesModifiedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
  }) : super(type: 'pending_messages.modified');

  factory PendingMessagesModifiedEvent._fromJson(Map<String, dynamic> json) {
    return PendingMessagesModifiedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
    );
  }
}

final class AssistantTurnStartEvent extends SessionEvent {
  const AssistantTurnStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.turnId,
  }) : super(type: 'assistant.turn_start');

  final String turnId;

  factory AssistantTurnStartEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantTurnStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      turnId: d['turnId'] as String? ?? '',
    );
  }
}

final class AssistantIntentEvent extends SessionEvent {
  const AssistantIntentEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.intent,
  }) : super(type: 'assistant.intent');

  final String intent;

  factory AssistantIntentEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantIntentEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      intent: d['intent'] as String? ?? '',
    );
  }
}

final class AssistantReasoningEvent extends SessionEvent {
  const AssistantReasoningEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.reasoningId,
    required this.content,
  }) : super(type: 'assistant.reasoning');

  final String reasoningId;
  final String content;

  factory AssistantReasoningEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantReasoningEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      reasoningId: d['reasoningId'] as String? ?? '',
      content: d['content'] as String? ?? '',
    );
  }
}

final class AssistantReasoningDeltaEvent extends SessionEvent {
  const AssistantReasoningDeltaEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.reasoningId,
    required this.deltaContent,
  }) : super(type: 'assistant.reasoning_delta');

  final String reasoningId;
  final String deltaContent;

  factory AssistantReasoningDeltaEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantReasoningDeltaEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      reasoningId: d['reasoningId'] as String? ?? '',
      deltaContent: d['deltaContent'] as String? ?? '',
    );
  }
}

final class AssistantStreamingDeltaEvent extends SessionEvent {
  const AssistantStreamingDeltaEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.totalResponseSizeBytes,
  }) : super(type: 'assistant.streaming_delta');

  final int totalResponseSizeBytes;

  factory AssistantStreamingDeltaEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantStreamingDeltaEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      totalResponseSizeBytes: d['totalResponseSizeBytes'] as int? ?? 0,
    );
  }
}

final class AssistantMessageEvent extends SessionEvent {
  const AssistantMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.messageId,
    required this.content,
    this.toolRequests,
    this.reasoningOpaque,
    this.reasoningText,
    this.encryptedContent,
    this.phase,
    this.parentToolCallId,
  }) : super(type: 'assistant.message');

  final String messageId;
  final String content;
  final List<dynamic>? toolRequests;
  final String? reasoningOpaque;
  final String? reasoningText;
  final String? encryptedContent;
  final String? phase;
  final String? parentToolCallId;

  factory AssistantMessageEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      messageId: _required<String>(d, 'messageId', 'assistant.message'),
      content: _required<String>(d, 'content', 'assistant.message'),
      toolRequests: d['toolRequests'] as List<dynamic>?,
      reasoningOpaque: d['reasoningOpaque'] as String?,
      reasoningText: d['reasoningText'] as String?,
      encryptedContent: d['encryptedContent'] as String?,
      phase: d['phase'] as String?,
      parentToolCallId: d['parentToolCallId'] as String?,
    );
  }
}

final class AssistantMessageDeltaEvent extends SessionEvent {
  const AssistantMessageDeltaEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.messageId,
    required this.deltaContent,
    this.parentToolCallId,
  }) : super(type: 'assistant.message_delta');

  final String messageId;
  final String deltaContent;
  final String? parentToolCallId;

  factory AssistantMessageDeltaEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantMessageDeltaEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      messageId: _required<String>(d, 'messageId', 'assistant.message_delta'),
      deltaContent:
          _required<String>(d, 'deltaContent', 'assistant.message_delta'),
      parentToolCallId: d['parentToolCallId'] as String?,
    );
  }
}

final class AssistantTurnEndEvent extends SessionEvent {
  const AssistantTurnEndEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.turnId,
  }) : super(type: 'assistant.turn_end');

  final String turnId;

  factory AssistantTurnEndEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantTurnEndEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      turnId: d['turnId'] as String? ?? '',
    );
  }
}

final class AssistantUsageEvent extends SessionEvent {
  const AssistantUsageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.model,
    this.inputTokens,
    this.outputTokens,
    this.cacheReadTokens,
    this.cacheWriteTokens,
    this.cost,
    this.duration,
    this.initiator,
    this.apiCallId,
    this.providerCallId,
    this.parentToolCallId,
    this.quotaSnapshots,
  }) : super(type: 'assistant.usage');

  final String model;
  final int? inputTokens;
  final int? outputTokens;
  final int? cacheReadTokens;
  final int? cacheWriteTokens;
  final num? cost;
  final num? duration;
  final String? initiator;
  final String? apiCallId;
  final String? providerCallId;
  final String? parentToolCallId;
  final Map<String, dynamic>? quotaSnapshots;

  factory AssistantUsageEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AssistantUsageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      model: d['model'] as String? ?? '',
      inputTokens: d['inputTokens'] as int?,
      outputTokens: d['outputTokens'] as int?,
      cacheReadTokens: d['cacheReadTokens'] as int?,
      cacheWriteTokens: d['cacheWriteTokens'] as int?,
      cost: d['cost'] as num?,
      duration: d['duration'] as num?,
      initiator: d['initiator'] as String?,
      apiCallId: d['apiCallId'] as String?,
      providerCallId: d['providerCallId'] as String?,
      parentToolCallId: d['parentToolCallId'] as String?,
      quotaSnapshots: d['quotaSnapshots'] as Map<String, dynamic>?,
    );
  }
}

// ── Abort Event ─────────────────────────────────────────────────────────────

final class AbortEvent extends SessionEvent {
  const AbortEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.reason,
  }) : super(type: 'abort');

  final String reason;

  factory AbortEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return AbortEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      reason: d['reason'] as String? ?? '',
    );
  }
}

// ── Tool Events ─────────────────────────────────────────────────────────────

final class ToolUserRequestedEvent extends SessionEvent {
  const ToolUserRequestedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.toolName,
    this.arguments,
  }) : super(type: 'tool.user_requested');

  final String toolCallId;
  final String toolName;
  final dynamic arguments;

  factory ToolUserRequestedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return ToolUserRequestedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: d['toolCallId'] as String? ?? '',
      toolName: d['toolName'] as String? ?? '',
      arguments: d['arguments'],
    );
  }
}

final class ToolExecutionStartEvent extends SessionEvent {
  const ToolExecutionStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.toolName,
    this.arguments,
    this.mcpServerName,
    this.mcpToolName,
    this.parentToolCallId,
  }) : super(type: 'tool.execution_start');

  final String toolCallId;
  final String toolName;
  final dynamic arguments;
  final String? mcpServerName;
  final String? mcpToolName;
  final String? parentToolCallId;

  factory ToolExecutionStartEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return ToolExecutionStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: d['toolCallId'] as String? ?? '',
      toolName: d['toolName'] as String? ?? '',
      arguments: d['arguments'],
      mcpServerName: d['mcpServerName'] as String?,
      mcpToolName: d['mcpToolName'] as String?,
      parentToolCallId: d['parentToolCallId'] as String?,
    );
  }
}

final class ToolExecutionPartialResultEvent extends SessionEvent {
  const ToolExecutionPartialResultEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.toolCallId,
    required this.partialOutput,
  }) : super(type: 'tool.execution_partial_result');

  final String toolCallId;
  final String partialOutput;

  factory ToolExecutionPartialResultEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return ToolExecutionPartialResultEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      toolCallId: d['toolCallId'] as String? ?? '',
      partialOutput: d['partialOutput'] as String? ?? '',
    );
  }
}

final class ToolExecutionProgressEvent extends SessionEvent {
  const ToolExecutionProgressEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral = true,
    required this.toolCallId,
    required this.progressMessage,
  }) : super(type: 'tool.execution_progress');

  final String toolCallId;
  final String progressMessage;

  factory ToolExecutionProgressEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return ToolExecutionProgressEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? true,
      toolCallId: d['toolCallId'] as String? ?? '',
      progressMessage: d['progressMessage'] as String? ?? '',
    );
  }
}

final class ToolExecutionCompleteEvent extends SessionEvent {
  const ToolExecutionCompleteEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.success,
    this.isUserRequested,
    this.result,
    this.error,
    this.toolTelemetry,
    this.parentToolCallId,
  }) : super(type: 'tool.execution_complete');

  final String toolCallId;
  final bool success;
  final bool? isUserRequested;

  /// Structured result: { content, detailedContent?, contents? }.
  final Map<String, dynamic>? result;

  /// Error info: { message, code? }.
  final Map<String, dynamic>? error;
  final Map<String, dynamic>? toolTelemetry;
  final String? parentToolCallId;

  factory ToolExecutionCompleteEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return ToolExecutionCompleteEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: _required<String>(d, 'toolCallId', 'tool.execution_complete'),
      success: _required<bool>(d, 'success', 'tool.execution_complete'),
      isUserRequested: d['isUserRequested'] as bool?,
      result: d['result'] as Map<String, dynamic>?,
      error: d['error'] as Map<String, dynamic>?,
      toolTelemetry: d['toolTelemetry'] as Map<String, dynamic>?,
      parentToolCallId: d['parentToolCallId'] as String?,
    );
  }
}

// ── Skill & Sub-agent Events ────────────────────────────────────────────────

final class SkillInvokedEvent extends SessionEvent {
  const SkillInvokedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.name,
    required this.path,
    required this.content,
    this.allowedTools,
  }) : super(type: 'skill.invoked');

  final String name;
  final String path;
  final String content;
  final List<String>? allowedTools;

  factory SkillInvokedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SkillInvokedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      name: d['name'] as String? ?? '',
      path: d['path'] as String? ?? '',
      content: d['content'] as String? ?? '',
      allowedTools: (d['allowedTools'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

final class SubagentStartedEvent extends SessionEvent {
  const SubagentStartedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.agentName,
    required this.agentDisplayName,
    required this.agentDescription,
  }) : super(type: 'subagent.started');

  final String toolCallId;
  final String agentName;
  final String agentDisplayName;
  final String agentDescription;

  factory SubagentStartedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SubagentStartedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: d['toolCallId'] as String? ?? '',
      agentName: d['agentName'] as String? ?? '',
      agentDisplayName: d['agentDisplayName'] as String? ?? '',
      agentDescription: d['agentDescription'] as String? ?? '',
    );
  }
}

final class SubagentCompletedEvent extends SessionEvent {
  const SubagentCompletedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.agentName,
    required this.agentDisplayName,
  }) : super(type: 'subagent.completed');

  final String toolCallId;
  final String agentName;
  final String agentDisplayName;

  factory SubagentCompletedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SubagentCompletedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: d['toolCallId'] as String? ?? '',
      agentName: d['agentName'] as String? ?? '',
      agentDisplayName: d['agentDisplayName'] as String? ?? '',
    );
  }
}

final class SubagentFailedEvent extends SessionEvent {
  const SubagentFailedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolCallId,
    required this.agentName,
    required this.agentDisplayName,
    required this.error,
  }) : super(type: 'subagent.failed');

  final String toolCallId;
  final String agentName;
  final String agentDisplayName;
  final String error;

  factory SubagentFailedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SubagentFailedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolCallId: d['toolCallId'] as String? ?? '',
      agentName: d['agentName'] as String? ?? '',
      agentDisplayName: d['agentDisplayName'] as String? ?? '',
      error: d['error'] as String? ?? '',
    );
  }
}

final class SubagentSelectedEvent extends SessionEvent {
  const SubagentSelectedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.agentName,
    required this.agentDisplayName,
    this.tools,
  }) : super(type: 'subagent.selected');

  final String agentName;
  final String agentDisplayName;
  final List<String>? tools;

  factory SubagentSelectedEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SubagentSelectedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      agentName: d['agentName'] as String? ?? '',
      agentDisplayName: d['agentDisplayName'] as String? ?? '',
      tools: (d['tools'] as List<dynamic>?)?.cast<String>(),
    );
  }
}

// ── Hook Events ─────────────────────────────────────────────────────────────

final class HookStartEvent extends SessionEvent {
  const HookStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.hookInvocationId,
    required this.hookType,
    this.input,
  }) : super(type: 'hook.start');

  final String hookInvocationId;
  final String hookType;
  final dynamic input;

  factory HookStartEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return HookStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      hookInvocationId: d['hookInvocationId'] as String? ?? '',
      hookType: d['hookType'] as String? ?? '',
      input: d['input'],
    );
  }
}

final class HookEndEvent extends SessionEvent {
  const HookEndEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.hookInvocationId,
    required this.hookType,
    this.output,
    required this.success,
    this.error,
  }) : super(type: 'hook.end');

  final String hookInvocationId;
  final String hookType;
  final dynamic output;
  final bool success;

  /// Error info: { message, stack? }.
  final Map<String, dynamic>? error;

  factory HookEndEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return HookEndEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      hookInvocationId: d['hookInvocationId'] as String? ?? '',
      hookType: d['hookType'] as String? ?? '',
      output: d['output'],
      success: d['success'] as bool? ?? false,
      error: d['error'] as Map<String, dynamic>?,
    );
  }
}

// ── System Message ──────────────────────────────────────────────────────────

final class SystemMessageEvent extends SessionEvent {
  const SystemMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
    required this.role,
    this.name,
    this.metadata,
  }) : super(type: 'system.message');

  final String content;

  /// One of "system", "developer".
  final String role;
  final String? name;
  final Map<String, dynamic>? metadata;

  factory SystemMessageEvent._fromJson(Map<String, dynamic> json) {
    final d = _data(json);
    return SystemMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: d['content'] as String? ?? '',
      role: d['role'] as String? ?? 'system',
      name: d['name'] as String?,
      metadata: d['metadata'] as Map<String, dynamic>?,
    );
  }
}

// ── Unknown / Fallback ──────────────────────────────────────────────────────

/// Catch-all for unknown or future event types.
final class UnknownEvent extends SessionEvent {
  const UnknownEvent({
    required super.id,
    required super.timestamp,
    required super.type,
    super.parentId,
    super.ephemeral,
    required this.data,
  });

  /// Raw JSON data of the event.
  final Map<String, dynamic> data;

  factory UnknownEvent._fromJson(Map<String, dynamic> json, String type) {
    return UnknownEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      type: type,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      data: json,
    );
  }
}

// ── Factory Registry ────────────────────────────────────────────────────────

/// Maps event type strings to factory constructors.
final Map<String, SessionEvent Function(Map<String, dynamic>)> _factories = {
  // Session lifecycle
  'session.start': SessionStartEvent._fromJson,
  'session.resume': SessionResumeEvent._fromJson,
  'session.error': SessionErrorEvent._fromJson,
  'session.idle': SessionIdleEvent._fromJson,
  'session.title_changed': SessionTitleChangedEvent._fromJson,
  'session.info': SessionInfoEvent._fromJson,
  'session.warning': SessionWarningEvent._fromJson,
  'session.model_change': SessionModelChangeEvent._fromJson,
  'session.mode_changed': SessionModeChangedEvent._fromJson,
  'session.plan_changed': SessionPlanChangedEvent._fromJson,
  'session.workspace_file_changed': SessionWorkspaceFileChangedEvent._fromJson,
  'session.handoff': SessionHandoffEvent._fromJson,
  'session.truncation': SessionTruncationEvent._fromJson,
  'session.snapshot_rewind': SessionSnapshotRewindEvent._fromJson,
  'session.shutdown': SessionShutdownEvent._fromJson,
  'session.context_changed': SessionContextChangedEvent._fromJson,
  'session.usage_info': SessionUsageInfoEvent._fromJson,
  'session.compaction_start': SessionCompactionStartEvent._fromJson,
  'session.compaction_complete': SessionCompactionCompleteEvent._fromJson,
  'session.task_complete': SessionTaskCompleteEvent._fromJson,
  // Messages
  'user.message': UserMessageEvent._fromJson,
  'pending_messages.modified': PendingMessagesModifiedEvent._fromJson,
  'assistant.turn_start': AssistantTurnStartEvent._fromJson,
  'assistant.intent': AssistantIntentEvent._fromJson,
  'assistant.reasoning': AssistantReasoningEvent._fromJson,
  'assistant.reasoning_delta': AssistantReasoningDeltaEvent._fromJson,
  'assistant.streaming_delta': AssistantStreamingDeltaEvent._fromJson,
  'assistant.message': AssistantMessageEvent._fromJson,
  'assistant.message_delta': AssistantMessageDeltaEvent._fromJson,
  'assistant.turn_end': AssistantTurnEndEvent._fromJson,
  'assistant.usage': AssistantUsageEvent._fromJson,
  // Abort
  'abort': AbortEvent._fromJson,
  // Tools
  'tool.user_requested': ToolUserRequestedEvent._fromJson,
  'tool.execution_start': ToolExecutionStartEvent._fromJson,
  'tool.execution_partial_result': ToolExecutionPartialResultEvent._fromJson,
  'tool.execution_progress': ToolExecutionProgressEvent._fromJson,
  'tool.execution_complete': ToolExecutionCompleteEvent._fromJson,
  // Skills & subagents
  'skill.invoked': SkillInvokedEvent._fromJson,
  'subagent.started': SubagentStartedEvent._fromJson,
  'subagent.completed': SubagentCompletedEvent._fromJson,
  'subagent.failed': SubagentFailedEvent._fromJson,
  'subagent.selected': SubagentSelectedEvent._fromJson,
  // Hooks
  'hook.start': HookStartEvent._fromJson,
  'hook.end': HookEndEvent._fromJson,
  // System
  'system.message': SystemMessageEvent._fromJson,
};
