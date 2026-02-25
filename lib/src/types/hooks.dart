/// Lifecycle hooks for Copilot sessions.
///
/// Hooks are invoked by the CLI server at specific points during
/// the agent's execution lifecycle.
class SessionHooks {
  const SessionHooks({
    this.onPreToolUse,
    this.onPostToolUse,
    this.onUserPromptSubmitted,
    this.onSessionStart,
    this.onSessionEnd,
    this.onErrorOccurred,
  });

  /// Called before a tool is executed. Can modify or reject the tool call.
  final HookHandler<PreToolUseInput, PreToolUseOutput>? onPreToolUse;

  /// Called after a tool completes. Can inspect or modify the result.
  final HookHandler<PostToolUseInput, PostToolUseOutput>? onPostToolUse;

  /// Called when the user submits a prompt.
  final HookHandler<UserPromptSubmittedInput, UserPromptSubmittedOutput>?
      onUserPromptSubmitted;

  /// Called when a session starts.
  final HookHandler<SessionStartInput, SessionStartOutput>? onSessionStart;

  /// Called when a session ends.
  final HookHandler<SessionEndInput, SessionEndOutput>? onSessionEnd;

  /// Called when an error occurs.
  final HookHandler<ErrorOccurredInput, ErrorOccurredOutput>? onErrorOccurred;

  /// Whether any hooks are registered.
  bool get hasHooks =>
      onPreToolUse != null ||
      onPostToolUse != null ||
      onUserPromptSubmitted != null ||
      onSessionStart != null ||
      onSessionEnd != null ||
      onErrorOccurred != null;

  /// Dispatches a hook invocation by type.
  Future<dynamic> invoke(
    String hookType,
    dynamic input,
    String sessionId,
  ) async {
    final invocation = HookInvocation(sessionId: sessionId);

    switch (hookType) {
      case 'preToolUse':
        if (onPreToolUse != null) {
          return await onPreToolUse!(
            PreToolUseInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'postToolUse':
        if (onPostToolUse != null) {
          return await onPostToolUse!(
            PostToolUseInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'userPromptSubmitted':
        if (onUserPromptSubmitted != null) {
          return await onUserPromptSubmitted!(
            UserPromptSubmittedInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'sessionStart':
        if (onSessionStart != null) {
          return await onSessionStart!(
            SessionStartInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'sessionEnd':
        if (onSessionEnd != null) {
          return await onSessionEnd!(
            SessionEndInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'errorOccurred':
        if (onErrorOccurred != null) {
          return await onErrorOccurred!(
            ErrorOccurredInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
    }
    return null;
  }
}

/// Hook handler function type.
typedef HookHandler<TInput, TOutput> = Future<TOutput?> Function(
  TInput input,
  HookInvocation invocation,
);

/// Context for hook invocations.
class HookInvocation {
  const HookInvocation({required this.sessionId});

  final String sessionId;
}

// ── Base Hook Input ─────────────────────────────────────────────────────────

/// Base fields present on all hook inputs from the CLI.
class BaseHookInput {
  const BaseHookInput({required this.timestamp, required this.cwd});

  /// Unix timestamp (milliseconds since epoch) when the hook was triggered.
  final num timestamp;

  /// Working directory of the session.
  final String cwd;
}

// ── Hook Input/Output Types ─────────────────────────────────────────────────

/// Input for the preToolUse hook.
class PreToolUseInput extends BaseHookInput {
  const PreToolUseInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    this.toolArgs,
  });

  final String toolName;
  final dynamic toolArgs;

  factory PreToolUseInput.fromJson(Map<String, dynamic> json) {
    return PreToolUseInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      toolName: json['toolName'] as String,
      toolArgs: json['toolArgs'] ?? json['arguments'],
    );
  }
}

/// Output for the preToolUse hook.
class PreToolUseOutput {
  const PreToolUseOutput({
    this.permissionDecision,
    this.permissionDecisionReason,
    this.modifiedArgs,
    this.additionalContext,
    this.suppressOutput,
  });

  /// `"allow"`, `"deny"`, or `"ask"`.
  final String? permissionDecision;
  final String? permissionDecisionReason;
  final dynamic modifiedArgs;

  /// Extra context to include in the conversation.
  final String? additionalContext;

  /// If true, suppress tool output from the user-visible log.
  final bool? suppressOutput;

  Map<String, dynamic> toJson() => {
        if (permissionDecision != null)
          'permissionDecision': permissionDecision,
        if (permissionDecisionReason != null)
          'permissionDecisionReason': permissionDecisionReason,
        if (modifiedArgs != null) 'modifiedArgs': modifiedArgs,
        if (additionalContext != null) 'additionalContext': additionalContext,
        if (suppressOutput != null) 'suppressOutput': suppressOutput,
      };
}

/// Input for the postToolUse hook.
class PostToolUseInput extends BaseHookInput {
  const PostToolUseInput({
    required super.timestamp,
    required super.cwd,
    required this.toolName,
    this.toolArgs,
    this.toolResult,
  });

  final String toolName;
  final dynamic toolArgs;
  final dynamic toolResult;

  factory PostToolUseInput.fromJson(Map<String, dynamic> json) {
    return PostToolUseInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      toolName: json['toolName'] as String,
      toolArgs: json['toolArgs'] ?? json['arguments'],
      toolResult: json['toolResult'] ?? json['result'],
    );
  }
}

/// Output for the postToolUse hook.
class PostToolUseOutput {
  const PostToolUseOutput({
    this.modifiedResult,
    this.additionalContext,
    this.suppressOutput,
  });

  final dynamic modifiedResult;
  final String? additionalContext;
  final bool? suppressOutput;

  Map<String, dynamic> toJson() => {
        if (modifiedResult != null) 'modifiedResult': modifiedResult,
        if (additionalContext != null) 'additionalContext': additionalContext,
        if (suppressOutput != null) 'suppressOutput': suppressOutput,
      };
}

/// Input for the userPromptSubmitted hook.
class UserPromptSubmittedInput extends BaseHookInput {
  const UserPromptSubmittedInput({
    required super.timestamp,
    required super.cwd,
    required this.prompt,
  });

  final String prompt;

  factory UserPromptSubmittedInput.fromJson(Map<String, dynamic> json) {
    return UserPromptSubmittedInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      prompt: json['prompt'] as String,
    );
  }
}

/// Output for the userPromptSubmitted hook.
class UserPromptSubmittedOutput {
  const UserPromptSubmittedOutput({
    this.modifiedPrompt,
    this.additionalContext,
    this.suppressOutput,
  });

  final String? modifiedPrompt;
  final String? additionalContext;
  final bool? suppressOutput;

  Map<String, dynamic> toJson() => {
        if (modifiedPrompt != null) 'modifiedPrompt': modifiedPrompt,
        if (additionalContext != null) 'additionalContext': additionalContext,
        if (suppressOutput != null) 'suppressOutput': suppressOutput,
      };
}

/// Input for the sessionStart hook.
class SessionStartInput extends BaseHookInput {
  const SessionStartInput({
    required super.timestamp,
    required super.cwd,
    required this.source,
    this.initialPrompt,
  });

  /// `"startup"`, `"resume"`, or `"new"`.
  final String source;
  final String? initialPrompt;

  factory SessionStartInput.fromJson(Map<String, dynamic> json) {
    return SessionStartInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      source: json['source'] as String? ?? 'new',
      initialPrompt: json['initialPrompt'] as String?,
    );
  }
}

/// Output for the sessionStart hook.
class SessionStartOutput {
  const SessionStartOutput({
    this.additionalContext,
    this.modifiedConfig,
  });

  final String? additionalContext;
  final Map<String, dynamic>? modifiedConfig;

  Map<String, dynamic> toJson() => {
        if (additionalContext != null) 'additionalContext': additionalContext,
        if (modifiedConfig != null) 'modifiedConfig': modifiedConfig,
      };
}

/// Input for the sessionEnd hook.
class SessionEndInput extends BaseHookInput {
  const SessionEndInput({
    required super.timestamp,
    required super.cwd,
    required this.reason,
    this.finalMessage,
    this.error,
  });

  /// `"complete"`, `"error"`, `"abort"`, `"timeout"`, or `"user_exit"`.
  final String reason;
  final String? finalMessage;
  final String? error;

  factory SessionEndInput.fromJson(Map<String, dynamic> json) {
    return SessionEndInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      reason: json['reason'] as String? ?? 'complete',
      finalMessage: json['finalMessage'] as String?,
      error: json['error'] as String?,
    );
  }
}

/// Output for the sessionEnd hook.
class SessionEndOutput {
  const SessionEndOutput({
    this.suppressOutput,
    this.cleanupActions,
    this.sessionSummary,
  });

  final bool? suppressOutput;
  final List<String>? cleanupActions;
  final String? sessionSummary;

  Map<String, dynamic> toJson() => {
        if (suppressOutput != null) 'suppressOutput': suppressOutput,
        if (cleanupActions != null) 'cleanupActions': cleanupActions,
        if (sessionSummary != null) 'sessionSummary': sessionSummary,
      };
}

/// Input for the errorOccurred hook.
class ErrorOccurredInput extends BaseHookInput {
  const ErrorOccurredInput({
    required super.timestamp,
    required super.cwd,
    required this.error,
    required this.errorContext,
    this.recoverable = false,
  });

  /// Error message.
  final String error;

  /// `"model_call"`, `"tool_execution"`, `"system"`, or `"user_input"`.
  final String errorContext;

  /// Whether the error is recoverable.
  final bool recoverable;

  factory ErrorOccurredInput.fromJson(Map<String, dynamic> json) {
    return ErrorOccurredInput(
      timestamp: json['timestamp'] as num? ?? 0,
      cwd: json['cwd'] as String? ?? '',
      error: json['error'] as String? ?? json['message'] as String? ?? '',
      errorContext: json['errorContext'] as String? ??
          json['errorType'] as String? ??
          'system',
      recoverable: json['recoverable'] as bool? ?? false,
    );
  }
}

/// Output for the errorOccurred hook.
class ErrorOccurredOutput {
  const ErrorOccurredOutput({
    this.suppressOutput,
    this.errorHandling,
    this.retryCount,
    this.userNotification,
  });

  final bool? suppressOutput;

  /// `"retry"`, `"skip"`, or `"abort"`.
  final String? errorHandling;
  final int? retryCount;
  final String? userNotification;

  Map<String, dynamic> toJson() => {
        if (suppressOutput != null) 'suppressOutput': suppressOutput,
        if (errorHandling != null) 'errorHandling': errorHandling,
        if (retryCount != null) 'retryCount': retryCount,
        if (userNotification != null) 'userNotification': userNotification,
      };
}
