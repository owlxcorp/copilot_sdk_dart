/// Session events — discriminated union using Dart 3 sealed classes.
///
/// The CLI server sends session events as JSON-RPC notifications
/// with method `session.event`. Each event has a `type` discriminator.
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

// ── Session Lifecycle Events ────────────────────────────────────────────────

final class SessionStartEvent extends SessionEvent {
  const SessionStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.sessionId,
    this.version,
    this.producer,
  }) : super(type: 'session.start');

  final String sessionId;
  final int? version;
  final String? producer;

  factory SessionStartEvent._fromJson(Map<String, dynamic> json) {
    return SessionStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      sessionId: json['sessionId'] as String,
      version: json['version'] as int?,
      producer: json['producer'] as String?,
    );
  }
}

final class SessionResumeEvent extends SessionEvent {
  const SessionResumeEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.sessionId,
    this.version,
    this.producer,
  }) : super(type: 'session.resume');

  final String sessionId;
  final int? version;
  final String? producer;

  factory SessionResumeEvent._fromJson(Map<String, dynamic> json) {
    return SessionResumeEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      sessionId: json['sessionId'] as String,
      version: json['version'] as int?,
      producer: json['producer'] as String?,
    );
  }
}

final class SessionErrorEvent extends SessionEvent {
  const SessionErrorEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.error,
    this.code,
  }) : super(type: 'session.error');

  final String error;
  final String? code;

  factory SessionErrorEvent._fromJson(Map<String, dynamic> json) {
    return SessionErrorEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      error: json['error'] as String,
      code: json['code'] as String?,
    );
  }
}

final class SessionIdleEvent extends SessionEvent {
  const SessionIdleEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.reason,
  }) : super(type: 'session.idle');

  final String? reason;

  factory SessionIdleEvent._fromJson(Map<String, dynamic> json) {
    return SessionIdleEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

final class SessionShutdownEvent extends SessionEvent {
  const SessionShutdownEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.reason,
  }) : super(type: 'session.shutdown');

  final String? reason;

  factory SessionShutdownEvent._fromJson(Map<String, dynamic> json) {
    return SessionShutdownEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}

final class SessionTitleChangedEvent extends SessionEvent {
  const SessionTitleChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.title,
  }) : super(type: 'session.title_changed');

  final String title;

  factory SessionTitleChangedEvent._fromJson(Map<String, dynamic> json) {
    return SessionTitleChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      title: json['title'] as String,
    );
  }
}

final class SessionModelChangeEvent extends SessionEvent {
  const SessionModelChangeEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.modelId,
    this.modelName,
  }) : super(type: 'session.model_change');

  final String modelId;
  final String? modelName;

  factory SessionModelChangeEvent._fromJson(Map<String, dynamic> json) {
    return SessionModelChangeEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      modelId: json['modelId'] as String,
      modelName: json['modelName'] as String?,
    );
  }
}

final class SessionModeChangedEvent extends SessionEvent {
  const SessionModeChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.mode,
  }) : super(type: 'session.mode_changed');

  final String mode;

  factory SessionModeChangedEvent._fromJson(Map<String, dynamic> json) {
    return SessionModeChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      mode: json['mode'] as String,
    );
  }
}

final class SessionPlanChangedEvent extends SessionEvent {
  const SessionPlanChangedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.plan,
  }) : super(type: 'session.plan_changed');

  final String? plan;

  factory SessionPlanChangedEvent._fromJson(Map<String, dynamic> json) {
    return SessionPlanChangedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      plan: json['plan'] as String?,
    );
  }
}

final class SessionTruncationEvent extends SessionEvent {
  const SessionTruncationEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    this.removedCount,
    this.remainingCount,
  }) : super(type: 'session.truncation');

  final int? removedCount;
  final int? remainingCount;

  factory SessionTruncationEvent._fromJson(Map<String, dynamic> json) {
    return SessionTruncationEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      removedCount: json['removedCount'] as int?,
      remainingCount: json['remainingCount'] as int?,
    );
  }
}

// ── Message Events ──────────────────────────────────────────────────────────

final class AssistantMessageEvent extends SessionEvent {
  const AssistantMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
    this.role,
  }) : super(type: 'assistant.message');

  final String content;
  final String? role;

  factory AssistantMessageEvent._fromJson(Map<String, dynamic> json) {
    return AssistantMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: json['content'] as String,
      role: json['role'] as String?,
    );
  }
}

final class AssistantThinkingEvent extends SessionEvent {
  const AssistantThinkingEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
  }) : super(type: 'assistant.thinking');

  final String content;

  factory AssistantThinkingEvent._fromJson(Map<String, dynamic> json) {
    return AssistantThinkingEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: json['content'] as String,
    );
  }
}

final class UserMessageEvent extends SessionEvent {
  const UserMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
  }) : super(type: 'user.message');

  final String content;

  factory UserMessageEvent._fromJson(Map<String, dynamic> json) {
    return UserMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: json['content'] as String,
    );
  }
}

final class SystemMessageEvent extends SessionEvent {
  const SystemMessageEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.content,
  }) : super(type: 'system.message');

  final String content;

  factory SystemMessageEvent._fromJson(Map<String, dynamic> json) {
    return SystemMessageEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      content: json['content'] as String,
    );
  }
}

// ── Tool Events ─────────────────────────────────────────────────────────────

final class ToolCallEvent extends SessionEvent {
  const ToolCallEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolName,
    required this.toolCallId,
    this.arguments,
  }) : super(type: 'tool.call');

  final String toolName;
  final String toolCallId;
  final dynamic arguments;

  factory ToolCallEvent._fromJson(Map<String, dynamic> json) {
    return ToolCallEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String,
      arguments: json['arguments'],
    );
  }
}

final class ToolExecutionStartEvent extends SessionEvent {
  const ToolExecutionStartEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolName,
    required this.toolCallId,
  }) : super(type: 'tool.execution_start');

  final String toolName;
  final String toolCallId;

  factory ToolExecutionStartEvent._fromJson(Map<String, dynamic> json) {
    return ToolExecutionStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String,
    );
  }
}

final class ToolExecutionPartialResultEvent extends SessionEvent {
  const ToolExecutionPartialResultEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolName,
    required this.toolCallId,
    required this.partialResult,
  }) : super(type: 'tool.execution_partial_result');

  final String toolName;
  final String toolCallId;
  final String partialResult;

  factory ToolExecutionPartialResultEvent._fromJson(Map<String, dynamic> json) {
    return ToolExecutionPartialResultEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String,
      partialResult: json['partialResult'] as String,
    );
  }
}

final class ToolExecutionCompleteEvent extends SessionEvent {
  const ToolExecutionCompleteEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.toolName,
    required this.toolCallId,
    this.result,
  }) : super(type: 'tool.execution_complete');

  final String toolName;
  final String toolCallId;
  final String? result;

  factory ToolExecutionCompleteEvent._fromJson(Map<String, dynamic> json) {
    return ToolExecutionCompleteEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String,
      result: json['result'] as String?,
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
    required this.skillName,
    this.reason,
  }) : super(type: 'skill.invoked');

  final String skillName;
  final String? reason;

  factory SkillInvokedEvent._fromJson(Map<String, dynamic> json) {
    return SkillInvokedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      skillName: json['skillName'] as String,
      reason: json['reason'] as String?,
    );
  }
}

final class SubagentStartedEvent extends SessionEvent {
  const SubagentStartedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.agentId,
    this.agentName,
  }) : super(type: 'subagent.started');

  final String agentId;
  final String? agentName;

  factory SubagentStartedEvent._fromJson(Map<String, dynamic> json) {
    return SubagentStartedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      agentId: json['agentId'] as String,
      agentName: json['agentName'] as String?,
    );
  }
}

final class SubagentCompletedEvent extends SessionEvent {
  const SubagentCompletedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.agentId,
    this.agentName,
    this.result,
  }) : super(type: 'subagent.completed');

  final String agentId;
  final String? agentName;
  final String? result;

  factory SubagentCompletedEvent._fromJson(Map<String, dynamic> json) {
    return SubagentCompletedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      agentId: json['agentId'] as String,
      agentName: json['agentName'] as String?,
      result: json['result'] as String?,
    );
  }
}

final class SubagentFailedEvent extends SessionEvent {
  const SubagentFailedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.agentId,
    this.agentName,
    this.error,
  }) : super(type: 'subagent.failed');

  final String agentId;
  final String? agentName;
  final String? error;

  factory SubagentFailedEvent._fromJson(Map<String, dynamic> json) {
    return SubagentFailedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      agentId: json['agentId'] as String,
      agentName: json['agentName'] as String?,
      error: json['error'] as String?,
    );
  }
}

final class SubagentSelectedEvent extends SessionEvent {
  const SubagentSelectedEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.agentId,
    this.agentName,
  }) : super(type: 'subagent.selected');

  final String agentId;
  final String? agentName;

  factory SubagentSelectedEvent._fromJson(Map<String, dynamic> json) {
    return SubagentSelectedEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      agentId: json['agentId'] as String,
      agentName: json['agentName'] as String?,
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
    required this.hookType,
  }) : super(type: 'hook.start');

  final String hookType;

  factory HookStartEvent._fromJson(Map<String, dynamic> json) {
    return HookStartEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      hookType: json['hookType'] as String,
    );
  }
}

final class HookEndEvent extends SessionEvent {
  const HookEndEvent({
    required super.id,
    required super.timestamp,
    super.parentId,
    super.ephemeral,
    required this.hookType,
    this.result,
  }) : super(type: 'hook.end');

  final String hookType;
  final dynamic result;

  factory HookEndEvent._fromJson(Map<String, dynamic> json) {
    return HookEndEvent(
      id: json['id'] as String,
      timestamp: json['timestamp'] as String,
      parentId: json['parentId'] as String?,
      ephemeral: json['ephemeral'] as bool? ?? false,
      hookType: json['hookType'] as String,
      result: json['result'],
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
  'session.start': SessionStartEvent._fromJson,
  'session.resume': SessionResumeEvent._fromJson,
  'session.error': SessionErrorEvent._fromJson,
  'session.idle': SessionIdleEvent._fromJson,
  'session.shutdown': SessionShutdownEvent._fromJson,
  'session.title_changed': SessionTitleChangedEvent._fromJson,
  'session.model_change': SessionModelChangeEvent._fromJson,
  'session.mode_changed': SessionModeChangedEvent._fromJson,
  'session.plan_changed': SessionPlanChangedEvent._fromJson,
  'session.truncation': SessionTruncationEvent._fromJson,
  'assistant.message': AssistantMessageEvent._fromJson,
  'assistant.thinking': AssistantThinkingEvent._fromJson,
  'user.message': UserMessageEvent._fromJson,
  'system.message': SystemMessageEvent._fromJson,
  'tool.call': ToolCallEvent._fromJson,
  'tool.execution_start': ToolExecutionStartEvent._fromJson,
  'tool.execution_partial_result': ToolExecutionPartialResultEvent._fromJson,
  'tool.execution_complete': ToolExecutionCompleteEvent._fromJson,
  'skill.invoked': SkillInvokedEvent._fromJson,
  'subagent.started': SubagentStartedEvent._fromJson,
  'subagent.completed': SubagentCompletedEvent._fromJson,
  'subagent.failed': SubagentFailedEvent._fromJson,
  'subagent.selected': SubagentSelectedEvent._fromJson,
  'hook.start': HookStartEvent._fromJson,
  'hook.end': HookEndEvent._fromJson,
};
