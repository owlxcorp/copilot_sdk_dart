import 'hooks.dart';
import 'tool_types.dart';

/// Configuration for creating a new session.
class SessionConfig {
  const SessionConfig({
    this.sessionId,
    this.clientName,
    this.model,
    this.systemMessage,
    this.infiniteSessions,
    this.streaming = true,
    this.tools = const [],
    this.availableTools,
    this.excludedTools,
    this.mcpServers = const {},
    this.customAgents = const [],
    this.skillDirectories = const [],
    this.disabledSkills = const [],
    this.hooks,
    this.provider,
    this.reasoningEffort,
    this.mode,
    this.attachments = const [],
    this.configDir,
    this.workingDirectory,
    required this.onPermissionRequest,
    this.onUserInputRequest,
  });

  /// Optional custom session ID.
  final String? sessionId;

  /// Client name for User-Agent header.
  final String? clientName;

  /// Model ID to use (e.g., "gpt-4", "claude-sonnet-4.5").
  final String? model;

  /// System message configuration.
  final SystemMessageConfig? systemMessage;

  /// Infinite session configuration with compaction thresholds.
  final InfiniteSessionConfig? infiniteSessions;

  /// Whether to stream events in real-time.
  final bool streaming;

  /// Custom tools to register with this session.
  final List<Tool> tools;

  /// List of built-in tool names to make available.
  final List<String>? availableTools;

  /// List of built-in tool names to exclude.
  final List<String>? excludedTools;

  /// MCP servers to connect to, keyed by server name.
  final Map<String, McpServerConfig> mcpServers;

  /// Custom agent configurations.
  final List<CustomAgentConfig> customAgents;

  /// Directories containing skill files.
  final List<String> skillDirectories;

  /// Skill names to disable.
  final List<String> disabledSkills;

  /// Lifecycle hooks.
  final SessionHooks? hooks;

  /// BYOK provider configuration.
  final ProviderConfig? provider;

  /// Reasoning effort level.
  final ReasoningEffort? reasoningEffort;

  /// Initial agent mode.
  final AgentMode? mode;

  /// Initial attachments.
  final List<Attachment> attachments;

  /// Override config directory location.
  final String? configDir;

  /// Working directory for tool operations.
  final String? workingDirectory;

  /// Handler for permission requests (required).
  final PermissionHandler onPermissionRequest;

  /// Handler for user input requests.
  final UserInputHandler? onUserInputRequest;

  /// Converts to JSON for the session.create RPC call.
  Map<String, dynamic> toJson() {
    return {
      if (sessionId != null) 'sessionId': sessionId,
      if (clientName != null) 'clientName': clientName,
      if (model != null) 'model': model,
      if (systemMessage != null) 'systemMessage': systemMessage!.toJson(),
      if (infiniteSessions != null)
        'infiniteSessions': infiniteSessions!.toJson(),
      'streaming': streaming,
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toRegistrationJson()).toList(),
      if (availableTools != null) 'availableTools': availableTools,
      if (excludedTools != null) 'excludedTools': excludedTools,
      if (mcpServers.isNotEmpty)
        'mcpServers': mcpServers.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (customAgents.isNotEmpty)
        'customAgents': customAgents.map((a) => a.toJson()).toList(),
      if (skillDirectories.isNotEmpty) 'skillDirectories': skillDirectories,
      if (disabledSkills.isNotEmpty) 'disabledSkills': disabledSkills,
      if (provider != null) 'provider': provider!.toJson(),
      if (reasoningEffort != null)
        'reasoningEffort': reasoningEffort!.toJsonValue(),
      if (mode != null) 'mode': mode!.toJsonValue(),
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
      if (configDir != null) 'configDir': configDir,
      if (workingDirectory != null) 'workingDirectory': workingDirectory,
      // Capability flags — required for CLI to know we handle these.
      'requestPermission': true,
      'requestUserInput': onUserInputRequest != null,
      'hooks': hooks?.hasHooks ?? false,
      'envValueMode': 'direct',
    };
  }
}

/// Configuration for resuming an existing session.
class ResumeSessionConfig {
  const ResumeSessionConfig({
    required this.sessionId,
    this.clientName,
    this.model,
    this.systemMessage,
    this.infiniteSessions,
    this.streaming,
    this.availableTools,
    this.excludedTools,
    this.mcpServers = const {},
    this.customAgents = const [],
    this.skillDirectories = const [],
    this.disabledSkills = const [],
    this.provider,
    this.reasoningEffort,
    this.configDir,
    this.workingDirectory,
    this.disableResume,
    required this.onPermissionRequest,
    this.onUserInputRequest,
    this.tools = const [],
    this.hooks,
  });

  final String sessionId;
  final String? clientName;
  final String? model;
  final SystemMessageConfig? systemMessage;
  final InfiniteSessionConfig? infiniteSessions;
  final bool? streaming;
  final List<String>? availableTools;
  final List<String>? excludedTools;
  final Map<String, McpServerConfig> mcpServers;
  final List<CustomAgentConfig> customAgents;
  final List<String> skillDirectories;
  final List<String> disabledSkills;
  final ProviderConfig? provider;
  final ReasoningEffort? reasoningEffort;
  final String? configDir;
  final String? workingDirectory;
  final bool? disableResume;
  final PermissionHandler onPermissionRequest;
  final UserInputHandler? onUserInputRequest;
  final List<Tool> tools;
  final SessionHooks? hooks;

  /// Converts to JSON for the session.resume RPC call.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      if (clientName != null) 'clientName': clientName,
      if (model != null) 'model': model,
      if (systemMessage != null) 'systemMessage': systemMessage!.toJson(),
      if (infiniteSessions != null)
        'infiniteSessions': infiniteSessions!.toJson(),
      if (streaming != null) 'streaming': streaming,
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toRegistrationJson()).toList(),
      if (availableTools != null) 'availableTools': availableTools,
      if (excludedTools != null) 'excludedTools': excludedTools,
      if (mcpServers.isNotEmpty)
        'mcpServers': mcpServers.map(
          (key, value) => MapEntry(key, value.toJson()),
        ),
      if (customAgents.isNotEmpty)
        'customAgents': customAgents.map((a) => a.toJson()).toList(),
      if (skillDirectories.isNotEmpty) 'skillDirectories': skillDirectories,
      if (disabledSkills.isNotEmpty) 'disabledSkills': disabledSkills,
      if (provider != null) 'provider': provider!.toJson(),
      if (reasoningEffort != null)
        'reasoningEffort': reasoningEffort!.toJsonValue(),
      if (configDir != null) 'configDir': configDir,
      if (workingDirectory != null) 'workingDirectory': workingDirectory,
      if (disableResume != null) 'disableResume': disableResume,
      'requestPermission': true,
      'requestUserInput': onUserInputRequest != null,
      'hooks': hooks?.hasHooks ?? false,
      'envValueMode': 'direct',
    };
  }
}

/// Options for sending a message.
/// Message delivery mode for `session.send`.
///
/// This controls how the message is delivered to the session queue.
/// Not to be confused with [AgentMode] which controls the agent's
/// operating behavior (interactive/plan/autopilot).
enum MessageDeliveryMode {
  /// Add to queue (default).
  enqueue,

  /// Send immediately, bypassing the queue.
  immediate;

  String toJsonValue() => name;

  static MessageDeliveryMode fromJson(String value) {
    return MessageDeliveryMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageDeliveryMode.enqueue,
    );
  }
}

class MessageOptions {
  const MessageOptions({
    required this.prompt,
    this.attachments = const [],
    this.mode,
  });

  final String prompt;
  final List<Attachment> attachments;

  /// Message delivery mode: [MessageDeliveryMode.enqueue] (default) or
  /// [MessageDeliveryMode.immediate].
  final MessageDeliveryMode? mode;

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
      if (mode != null) 'mode': mode!.toJsonValue(),
    };
  }
}

/// System message configuration.
sealed class SystemMessageConfig {
  const SystemMessageConfig();

  Map<String, dynamic> toJson();
}

/// Append mode: SDK-managed system message with optional appended content.
class SystemMessageAppend extends SystemMessageConfig {
  const SystemMessageAppend({this.content});

  final String? content;

  @override
  Map<String, dynamic> toJson() => {
        'mode': 'append',
        if (content != null) 'content': content,
      };
}

/// Replace mode: Fully custom system message.
class SystemMessageReplace extends SystemMessageConfig {
  const SystemMessageReplace({required this.content});

  final String content;

  @override
  Map<String, dynamic> toJson() => {
        'mode': 'replace',
        'content': content,
      };
}

/// Infinite session configuration with compaction thresholds.
class InfiniteSessionConfig {
  const InfiniteSessionConfig({
    this.enabled,
    this.backgroundCompactionThreshold,
    this.bufferExhaustionThreshold,
  });

  /// Whether infinite sessions are enabled.
  final bool? enabled;

  /// Context utilization threshold (0.0–1.0) at which background compaction
  /// starts. Default: 0.80.
  final double? backgroundCompactionThreshold;

  /// Context utilization threshold (0.0–1.0) at which the session blocks until
  /// compaction completes. Default: 0.95.
  final double? bufferExhaustionThreshold;

  Map<String, dynamic> toJson() => {
        if (enabled != null) 'enabled': enabled,
        if (backgroundCompactionThreshold != null)
          'backgroundCompactionThreshold': backgroundCompactionThreshold,
        if (bufferExhaustionThreshold != null)
          'bufferExhaustionThreshold': bufferExhaustionThreshold,
      };
}

/// MCP server configuration (sealed hierarchy).
sealed class McpServerConfig {
  const McpServerConfig({this.tools, this.timeout});

  /// Optional list of tool names to expose from this server.
  final List<String>? tools;

  /// Timeout in seconds for server operations.
  final int? timeout;

  Map<String, dynamic> toJson();
}

/// Local/stdio MCP server configuration.
class McpLocalServerConfig extends McpServerConfig {
  const McpLocalServerConfig({
    required this.command,
    this.args = const [],
    this.env,
    this.cwd,
    super.tools,
    super.timeout,
  });

  final String command;
  final List<String> args;
  final Map<String, String>? env;
  final String? cwd;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'stdio',
        'command': command,
        if (args.isNotEmpty) 'args': args,
        if (env != null) 'env': env,
        if (cwd != null) 'cwd': cwd,
        if (tools != null) 'tools': tools,
        if (timeout != null) 'timeout': timeout,
      };
}

/// Remote HTTP or SSE MCP server configuration.
class McpRemoteServerConfig extends McpServerConfig {
  const McpRemoteServerConfig({
    required this.type,
    required this.url,
    this.headers,
    super.tools,
    super.timeout,
  });

  /// Transport type: 'http' or 'sse'.
  final String type;

  /// Server URL.
  final String url;

  /// Optional headers for authentication.
  final Map<String, String>? headers;

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'url': url,
        if (headers != null) 'headers': headers,
        if (tools != null) 'tools': tools,
        if (timeout != null) 'timeout': timeout,
      };
}

/// Custom agent configuration.
class CustomAgentConfig {
  const CustomAgentConfig({
    required this.name,
    this.displayName,
    this.description,
    this.prompt,
    this.tools,
    this.mcpServers,
    this.infer,
  });

  final String name;
  final String? displayName;
  final String? description;

  /// System prompt for this agent (required upstream, optional in config).
  final String? prompt;
  final List<String>? tools;

  /// MCP servers available to this agent, keyed by name.
  final Map<String, McpServerConfig>? mcpServers;

  /// Whether to infer agent behavior from context.
  final bool? infer;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (displayName != null) 'displayName': displayName,
        if (description != null) 'description': description,
        if (prompt != null) 'prompt': prompt,
        if (tools != null) 'tools': tools,
        if (mcpServers != null)
          'mcpServers':
              mcpServers!.map((key, value) => MapEntry(key, value.toJson())),
        if (infer != null) 'infer': infer,
      };
}

/// BYOK (Bring Your Own Key) provider configuration.
class ProviderConfig {
  const ProviderConfig({
    required this.type,
    this.apiKey,
    this.baseUrl,
    this.wireApi,
    this.bearerToken,
    this.azure,
  });

  final String type;
  final String? apiKey;
  final String? baseUrl;

  /// Wire API format (e.g., 'openai').
  final String? wireApi;

  /// Bearer token for authentication.
  final String? bearerToken;

  /// Azure-specific provider options.
  final AzureProviderOptions? azure;

  Map<String, dynamic> toJson() => {
        'type': type,
        if (apiKey != null) 'apiKey': apiKey,
        if (baseUrl != null) 'baseUrl': baseUrl,
        if (wireApi != null) 'wireApi': wireApi,
        if (bearerToken != null) 'bearerToken': bearerToken,
        if (azure != null) 'azure': azure!.toJson(),
      };
}

/// Azure-specific provider options.
class AzureProviderOptions {
  const AzureProviderOptions({this.apiVersion});

  final String? apiVersion;

  Map<String, dynamic> toJson() => {
        if (apiVersion != null) 'apiVersion': apiVersion,
      };
}

/// Attachment for a message (sealed hierarchy).
sealed class Attachment {
  const Attachment();

  /// Creates a file attachment.
  factory Attachment.file(String path, {String? displayName}) = FileAttachment;

  /// Creates a directory attachment.
  factory Attachment.directory(String path, {String? displayName}) =
      DirectoryAttachment;

  /// Creates a selection attachment.
  factory Attachment.selection({
    required String filePath,
    String? displayName,
    SelectionRange? selection,
    String? text,
  }) = SelectionAttachment;

  Map<String, dynamic> toJson();
}

/// File attachment.
class FileAttachment extends Attachment {
  const FileAttachment(this.path, {this.displayName});

  final String path;
  final String? displayName;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'file',
        'path': path,
        if (displayName != null) 'displayName': displayName,
      };
}

/// Directory attachment.
class DirectoryAttachment extends Attachment {
  const DirectoryAttachment(this.path, {this.displayName});

  final String path;
  final String? displayName;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'directory',
        'path': path,
        if (displayName != null) 'displayName': displayName,
      };
}

/// Selection (code range) attachment.
class SelectionAttachment extends Attachment {
  const SelectionAttachment({
    required this.filePath,
    this.displayName,
    this.selection,
    this.text,
  });

  final String filePath;
  final String? displayName;
  final SelectionRange? selection;
  final String? text;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'selection',
        'filePath': filePath,
        if (displayName != null) 'displayName': displayName,
        if (selection != null) 'selection': selection!.toJson(),
        if (text != null) 'text': text,
      };
}

/// Line/column range for a selection attachment.
class SelectionRange {
  const SelectionRange({required this.start, required this.end});

  final SelectionPosition start;
  final SelectionPosition end;

  Map<String, dynamic> toJson() => {
        'start': start.toJson(),
        'end': end.toJson(),
      };
}

/// Line/character position within a file.
///
/// Uses `character` (not `column`) to match the upstream wire format.
class SelectionPosition {
  const SelectionPosition({required this.line, required this.character});

  final int line;
  final int character;

  Map<String, dynamic> toJson() => {'line': line, 'character': character};
}

/// Agent operating mode.
enum AgentMode {
  interactive,
  plan,
  autopilot;

  String toJsonValue() => name;

  static AgentMode fromJson(String value) {
    return AgentMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AgentMode.interactive,
    );
  }
}

/// Reasoning effort level.
enum ReasoningEffort {
  low,
  medium,
  high,
  xhigh;

  String toJsonValue() => name;
}

/// Handler for permission requests.
typedef PermissionHandler = Future<PermissionResult> Function(
  PermissionRequest request,
  PermissionInvocation invocation,
);

/// Handler for user input requests.
typedef UserInputHandler = Future<UserInputResponse> Function(
  UserInputRequest request,
  UserInputInvocation invocation,
);

/// Permission request from the CLI.
class PermissionRequest {
  const PermissionRequest({this.kind, this.toolCallId, this.data});

  /// The kind of permission being requested.
  /// Values: 'shell', 'write', 'mcp', 'read', 'url', 'custom-tool'.
  final String? kind;

  /// The tool call ID associated with this permission.
  final String? toolCallId;

  /// Additional request data (extension properties).
  final dynamic data;

  factory PermissionRequest.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return PermissionRequest(
        kind: json['kind'] as String?,
        toolCallId: json['toolCallId'] as String?,
        data: json,
      );
    }
    return PermissionRequest(data: json);
  }
}

/// Permission result to send back.
class PermissionResult {
  const PermissionResult({required this.kind, this.rules});

  final String kind;

  /// Optional rules to apply (e.g., 'always-allow' for specific tools).
  final List<Map<String, dynamic>>? rules;

  /// Pre-built: approve the permission request.
  static const approved = PermissionResult(kind: 'approved');

  /// Pre-built: deny the permission request.
  static const denied = PermissionResult(
    kind: 'denied-no-approval-rule-and-could-not-request-from-user',
  );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        if (rules != null) 'rules': rules,
      };
}

/// Context for a permission invocation.
class PermissionInvocation {
  const PermissionInvocation({required this.sessionId});

  final String sessionId;
}

/// User input request from the CLI.
class UserInputRequest {
  const UserInputRequest({
    required this.question,
    this.choices,
    this.allowFreeform,
  });

  final String question;
  final List<String>? choices;
  final bool? allowFreeform;

  factory UserInputRequest.fromJson(Map<String, dynamic> json) {
    return UserInputRequest(
      question: json['question'] as String,
      choices:
          (json['choices'] as List<dynamic>?)?.map((e) => e as String).toList(),
      allowFreeform: json['allowFreeform'] as bool?,
    );
  }
}

/// User input response.
class UserInputResponse {
  const UserInputResponse({
    required this.answer,
    this.wasFreeform = false,
  });

  final String answer;
  final bool wasFreeform;

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'wasFreeform': wasFreeform,
      };
}

/// Context for a user input invocation.
class UserInputInvocation {
  const UserInputInvocation({required this.sessionId});

  final String sessionId;
}

/// Convenience function to approve all permissions.
Future<PermissionResult> approveAllPermissions(
  PermissionRequest request,
  PermissionInvocation invocation,
) async {
  return PermissionResult.approved;
}

/// Alias matching the upstream SDK name `approveAll`.
///
/// Convenience [PermissionHandler] that approves every permission request.
const approveAll = approveAllPermissions;
