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

  /// Called before a tool is used. Can modify or reject the tool call.
  final HookHandler<PreToolUseInput, PreToolUseOutput>? onPreToolUse;

  /// Called after a tool completes. Can inspect or modify the result.
  final HookHandler<PostToolUseInput, PostToolUseOutput>? onPostToolUse;

  /// Called when the user submits a prompt.
  final HookHandler<UserPromptSubmittedInput, UserPromptSubmittedOutput>?
      onUserPromptSubmitted;

  /// Called when a session starts.
  final HookHandler<SessionStartInput, void>? onSessionStart;

  /// Called when a session ends.
  final HookHandler<SessionEndInput, void>? onSessionEnd;

  /// Called when an error occurs.
  final HookHandler<ErrorOccurredInput, void>? onErrorOccurred;

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
          await onSessionStart!(
            SessionStartInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'sessionEnd':
        if (onSessionEnd != null) {
          await onSessionEnd!(
            SessionEndInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
      case 'errorOccurred':
        if (onErrorOccurred != null) {
          await onErrorOccurred!(
            ErrorOccurredInput.fromJson(input as Map<String, dynamic>),
            invocation,
          );
        }
    }
    return null;
  }
}

/// Hook handler function type.
typedef HookHandler<TInput, TOutput> = Future<TOutput> Function(
  TInput input,
  HookInvocation invocation,
);

/// Context for hook invocations.
class HookInvocation {
  const HookInvocation({required this.sessionId});

  final String sessionId;
}

// ── Hook Input/Output Types ─────────────────────────────────────────────────

/// Input for the preToolUse hook.
class PreToolUseInput {
  const PreToolUseInput({
    required this.toolName,
    this.toolCallId,
    this.arguments,
  });

  final String toolName;
  final String? toolCallId;
  final dynamic arguments;

  factory PreToolUseInput.fromJson(Map<String, dynamic> json) {
    return PreToolUseInput(
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String?,
      arguments: json['arguments'],
    );
  }
}

/// Output for the preToolUse hook.
class PreToolUseOutput {
  const PreToolUseOutput({
    this.decision,
    this.message,
    this.updatedArguments,
  });

  /// 'approve', 'reject', or null (let the default handler decide).
  final String? decision;
  final String? message;
  final dynamic updatedArguments;

  Map<String, dynamic> toJson() => {
        if (decision != null) 'decision': decision,
        if (message != null) 'message': message,
        if (updatedArguments != null) 'updatedArguments': updatedArguments,
      };
}

/// Input for the postToolUse hook.
class PostToolUseInput {
  const PostToolUseInput({
    required this.toolName,
    this.toolCallId,
    this.result,
  });

  final String toolName;
  final String? toolCallId;
  final dynamic result;

  factory PostToolUseInput.fromJson(Map<String, dynamic> json) {
    return PostToolUseInput(
      toolName: json['toolName'] as String,
      toolCallId: json['toolCallId'] as String?,
      result: json['result'],
    );
  }
}

/// Output for the postToolUse hook.
class PostToolUseOutput {
  const PostToolUseOutput({this.updatedResult});

  final dynamic updatedResult;

  Map<String, dynamic> toJson() => {
        if (updatedResult != null) 'updatedResult': updatedResult,
      };
}

/// Input for the userPromptSubmitted hook.
class UserPromptSubmittedInput {
  const UserPromptSubmittedInput({required this.prompt});

  final String prompt;

  factory UserPromptSubmittedInput.fromJson(Map<String, dynamic> json) {
    return UserPromptSubmittedInput(prompt: json['prompt'] as String);
  }
}

/// Output for the userPromptSubmitted hook.
class UserPromptSubmittedOutput {
  const UserPromptSubmittedOutput({this.updatedPrompt});

  final String? updatedPrompt;

  Map<String, dynamic> toJson() => {
        if (updatedPrompt != null) 'updatedPrompt': updatedPrompt,
      };
}

/// Input for the sessionStart hook.
class SessionStartInput {
  const SessionStartInput({required this.sessionId});

  final String sessionId;

  factory SessionStartInput.fromJson(Map<String, dynamic> json) {
    return SessionStartInput(sessionId: json['sessionId'] as String);
  }
}

/// Input for the sessionEnd hook.
class SessionEndInput {
  const SessionEndInput({required this.sessionId, this.summary});

  final String sessionId;
  final String? summary;

  factory SessionEndInput.fromJson(Map<String, dynamic> json) {
    return SessionEndInput(
      sessionId: json['sessionId'] as String,
      summary: json['summary'] as String?,
    );
  }
}

/// Input for the errorOccurred hook.
class ErrorOccurredInput {
  const ErrorOccurredInput({
    required this.errorType,
    required this.message,
    this.stack,
  });

  final String errorType;
  final String message;
  final String? stack;

  factory ErrorOccurredInput.fromJson(Map<String, dynamic> json) {
    return ErrorOccurredInput(
      errorType: json['errorType'] as String,
      message: json['message'] as String,
      stack: json['stack'] as String?,
    );
  }
}
