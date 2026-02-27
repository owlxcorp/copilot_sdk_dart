/// Authentication and account-related types.
library;

/// Response from auth.getStatus.
class GetAuthStatusResponse {
  const GetAuthStatusResponse({
    required this.isAuthenticated,
    this.authType,
    this.host,
    this.login,
    this.statusMessage,
  });

  final bool isAuthenticated;
  final String? authType;
  final String? host;
  final String? login;
  final String? statusMessage;

  factory GetAuthStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetAuthStatusResponse(
      isAuthenticated: json['isAuthenticated'] as bool,
      authType: json['authType'] as String?,
      host: json['host'] as String?,
      login: json['login'] as String?,
      statusMessage: json['statusMessage'] as String?,
    );
  }
}

/// Response from status.get.
class GetStatusResponse {
  const GetStatusResponse({
    required this.version,
    required this.protocolVersion,
  });

  final String version;
  final int protocolVersion;

  factory GetStatusResponse.fromJson(Map<String, dynamic> json) {
    return GetStatusResponse(
      version: json['version'] as String,
      protocolVersion: json['protocolVersion'] as int,
    );
  }
}

/// Information about an available model.
class ModelInfo {
  const ModelInfo({
    required this.id,
    required this.name,
    required this.capabilities,
    this.policy,
    this.billing,
    this.supportedReasoningEfforts,
    this.defaultReasoningEffort,
  });

  final String id;
  final String name;
  final ModelCapabilities capabilities;
  final ModelPolicy? policy;
  final ModelBilling? billing;
  final List<String>? supportedReasoningEfforts;
  final String? defaultReasoningEffort;

  factory ModelInfo.fromJson(Map<String, dynamic> json) {
    return ModelInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      capabilities: ModelCapabilities.fromJson(
        json['capabilities'] as Map<String, dynamic>,
      ),
      policy: json['policy'] != null
          ? ModelPolicy.fromJson(json['policy'] as Map<String, dynamic>)
          : null,
      billing: json['billing'] != null
          ? ModelBilling.fromJson(json['billing'] as Map<String, dynamic>)
          : null,
      supportedReasoningEfforts:
          (json['supportedReasoningEfforts'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      defaultReasoningEffort: json['defaultReasoningEffort'] as String?,
    );
  }
}

/// Model capabilities and limits.
class ModelCapabilities {
  const ModelCapabilities({
    required this.supportsVision,
    required this.supportsReasoningEffort,
    this.maxPromptTokens,
    this.maxOutputTokens,
    required this.maxContextWindowTokens,
    this.vision,
  });

  final bool supportsVision;
  final bool supportsReasoningEffort;
  final int? maxPromptTokens;
  final int? maxOutputTokens;
  final int maxContextWindowTokens;

  /// Vision-specific limits (only present when the model supports vision).
  final VisionLimits? vision;

  factory ModelCapabilities.fromJson(Map<String, dynamic> json) {
    final supports = json['supports'] as Map<String, dynamic>;
    final limits = json['limits'] as Map<String, dynamic>;
    return ModelCapabilities(
      supportsVision: supports['vision'] as bool,
      supportsReasoningEffort: supports['reasoningEffort'] as bool,
      maxPromptTokens: limits['max_prompt_tokens'] as int?,
      maxOutputTokens: limits['max_output_tokens'] as int?,
      maxContextWindowTokens: limits['max_context_window_tokens'] as int,
      vision: limits['vision'] != null
          ? VisionLimits.fromJson(limits['vision'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Vision-specific model limits.
class VisionLimits {
  const VisionLimits({
    required this.supportedMediaTypes,
    required this.maxPromptImages,
    required this.maxPromptImageSize,
  });

  final List<String> supportedMediaTypes;
  final int maxPromptImages;
  final int maxPromptImageSize;

  factory VisionLimits.fromJson(Map<String, dynamic> json) {
    return VisionLimits(
      supportedMediaTypes:
          (json['supported_media_types'] as List<dynamic>).cast<String>(),
      maxPromptImages: json['max_prompt_images'] as int,
      maxPromptImageSize: json['max_prompt_image_size'] as int,
    );
  }
}

/// Model policy state.
class ModelPolicy {
  const ModelPolicy({required this.state, required this.terms});

  final String state;
  final String terms;

  factory ModelPolicy.fromJson(Map<String, dynamic> json) {
    return ModelPolicy(
      state: json['state'] as String,
      terms: json['terms'] as String,
    );
  }
}

/// Model billing information.
class ModelBilling {
  const ModelBilling({required this.multiplier});

  final double multiplier;

  factory ModelBilling.fromJson(Map<String, dynamic> json) {
    return ModelBilling(
      multiplier: (json['multiplier'] as num).toDouble(),
    );
  }
}

/// Account quota information.
class AccountQuota {
  const AccountQuota({required this.quotaSnapshots});

  final Map<String, QuotaSnapshot> quotaSnapshots;

  factory AccountQuota.fromJson(Map<String, dynamic> json) {
    final snapshots = json['quotaSnapshots'] as Map<String, dynamic>;
    return AccountQuota(
      quotaSnapshots: snapshots.map(
        (key, value) => MapEntry(
          key,
          QuotaSnapshot.fromJson(value as Map<String, dynamic>),
        ),
      ),
    );
  }
}

/// Quota snapshot for a specific quota type.
class QuotaSnapshot {
  const QuotaSnapshot({
    required this.entitlementRequests,
    required this.usedRequests,
    required this.remainingPercentage,
    required this.overage,
    required this.overageAllowedWithExhaustedQuota,
    this.resetDate,
  });

  final int entitlementRequests;
  final int usedRequests;
  final double remainingPercentage;
  final int overage;
  final bool overageAllowedWithExhaustedQuota;
  final String? resetDate;

  factory QuotaSnapshot.fromJson(Map<String, dynamic> json) {
    return QuotaSnapshot(
      entitlementRequests: json['entitlementRequests'] as int,
      usedRequests: json['usedRequests'] as int,
      remainingPercentage: (json['remainingPercentage'] as num).toDouble(),
      overage: json['overage'] as int,
      overageAllowedWithExhaustedQuota:
          json['overageAllowedWithExhaustedQuota'] as bool,
      resetDate: json['resetDate'] as String?,
    );
  }
}

/// Tool info from tools.list.
class ToolInfo {
  const ToolInfo({
    required this.name,
    required this.description,
    this.namespacedName,
    this.parameters,
    this.instructions,
  });

  final String name;
  final String description;
  final String? namespacedName;
  final Map<String, dynamic>? parameters;
  final String? instructions;

  factory ToolInfo.fromJson(Map<String, dynamic> json) {
    return ToolInfo(
      name: json['name'] as String,
      description: json['description'] as String,
      namespacedName: json['namespacedName'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>?,
      instructions: json['instructions'] as String?,
    );
  }
}

/// Metadata about a session.
class SessionMetadata {
  const SessionMetadata({
    required this.sessionId,
    required this.startTime,
    required this.modifiedTime,
    this.summary,
    required this.isRemote,
    this.context,
  });

  final String sessionId;
  final DateTime startTime;
  final DateTime modifiedTime;
  final String? summary;
  final bool isRemote;
  final SessionContext? context;

  factory SessionMetadata.fromJson(Map<String, dynamic> json) {
    return SessionMetadata(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      modifiedTime: DateTime.parse(json['modifiedTime'] as String),
      summary: json['summary'] as String?,
      isRemote: json['isRemote'] as bool? ?? false,
      context: json['context'] != null
          ? SessionContext.fromJson(json['context'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Working directory context for a session.
class SessionContext {
  const SessionContext({
    required this.cwd,
    this.gitRoot,
    this.repository,
    this.branch,
  });

  final String cwd;
  final String? gitRoot;
  final String? repository;
  final String? branch;

  factory SessionContext.fromJson(Map<String, dynamic> json) {
    return SessionContext(
      cwd: json['cwd'] as String,
      gitRoot: json['gitRoot'] as String?,
      repository: json['repository'] as String?,
      branch: json['branch'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'cwd': cwd,
        if (gitRoot != null) 'gitRoot': gitRoot,
        if (repository != null) 'repository': repository,
        if (branch != null) 'branch': branch,
      };
}

/// Filter options for listing sessions.
class SessionListFilter {
  const SessionListFilter({
    this.cwd,
    this.gitRoot,
    this.repository,
    this.branch,
  });

  final String? cwd;
  final String? gitRoot;
  final String? repository;
  final String? branch;

  Map<String, dynamic> toJson() => {
        if (cwd != null) 'cwd': cwd,
        if (gitRoot != null) 'gitRoot': gitRoot,
        if (repository != null) 'repository': repository,
        if (branch != null) 'branch': branch,
      };
}

/// Foreground session info.
class ForegroundSessionInfo {
  const ForegroundSessionInfo({this.sessionId, this.workspacePath});

  final String? sessionId;
  final String? workspacePath;

  factory ForegroundSessionInfo.fromJson(Map<String, dynamic> json) {
    return ForegroundSessionInfo(
      sessionId: json['sessionId'] as String?,
      workspacePath: json['workspacePath'] as String?,
    );
  }
}

/// Information about an agent.
class AgentInfo {
  const AgentInfo({
    required this.name,
    this.displayName,
    this.description,
  });

  final String name;
  final String? displayName;
  final String? description;

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      name: json['name'] as String,
      displayName: json['displayName'] as String?,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'displayName': displayName,
        'description': description,
      };
}

/// Result of a compaction operation.
class CompactionResult {
  const CompactionResult({
    required this.success,
    this.tokensRemoved,
    this.messagesRemoved,
  });

  final bool success;
  final int? tokensRemoved;
  final int? messagesRemoved;

  factory CompactionResult.fromJson(Map<String, dynamic> json) {
    return CompactionResult(
      success: json['success'] as bool,
      tokensRemoved: json['tokensRemoved'] as int?,
      messagesRemoved: json['messagesRemoved'] as int?,
    );
  }
}

/// Session lifecycle event type.
enum SessionLifecycleEventType {
  created,
  deleted,
  updated,
  foreground,
  background;

  static SessionLifecycleEventType fromString(String value) {
    // CLI sends prefixed values like "session.created", "session.deleted", etc.
    final bare = value.startsWith('session.') ? value.substring(8) : value;
    return SessionLifecycleEventType.values.firstWhere(
      (e) => e.name == bare,
      orElse: () => SessionLifecycleEventType.updated,
    );
  }
}

/// A session lifecycle event emitted by the CLI.
class SessionLifecycleEvent {
  const SessionLifecycleEvent({
    required this.type,
    required this.sessionId,
    this.metadata,
  });

  final SessionLifecycleEventType type;
  final String sessionId;
  final Map<String, dynamic>? metadata;

  factory SessionLifecycleEvent.fromJson(Map<String, dynamic> json) {
    return SessionLifecycleEvent(
      type: SessionLifecycleEventType.fromString(json['type'] as String),
      sessionId: json['sessionId'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Result of reading a session plan.
class PlanReadResult {
  const PlanReadResult({required this.exists, this.content});

  /// Whether plan.md exists in the workspace.
  final bool exists;

  /// The content of plan.md, or null if it does not exist.
  final String? content;
}
