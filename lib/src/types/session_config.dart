import 'hooks.dart';
import 'tool_types.dart';

/// Configuration for creating a new session.
class SessionConfig {
  const SessionConfig({
    this.model,
    this.systemMessage,
    this.infiniteSessions,
    this.streaming = true,
    this.tools = const [],
    this.availableTools,
    this.excludedTools,
    this.mcpServers = const [],
    this.customAgents = const [],
    this.skillDirectories = const [],
    this.hooks,
    this.provider,
    this.reasoningEffort,
    this.mode,
    this.attachments = const [],
    required this.onPermissionRequest,
    this.onUserInputRequest,
  });

  /// Model ID to use (e.g., "gpt-4", "claude-sonnet-4.5").
  final String? model;

  /// System message configuration.
  final SystemMessageConfig? systemMessage;

  /// Enable infinite sessions with workspace persistence.
  final bool? infiniteSessions;

  /// Whether to stream events in real-time.
  final bool streaming;

  /// Custom tools to register with this session.
  final List<Tool> tools;

  /// List of built-in tool names to make available.
  final List<String>? availableTools;

  /// List of built-in tool names to exclude.
  final List<String>? excludedTools;

  /// MCP servers to connect to.
  final List<McpServerConfig> mcpServers;

  /// Custom agent configurations.
  final List<CustomAgentConfig> customAgents;

  /// Directories containing skill files.
  final List<String> skillDirectories;

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

  /// Handler for permission requests (required).
  final PermissionHandler onPermissionRequest;

  /// Handler for user input requests.
  final UserInputHandler? onUserInputRequest;

  /// Converts to JSON for the session.create RPC call.
  Map<String, dynamic> toJson() {
    return {
      if (model != null) 'model': model,
      if (systemMessage != null) 'systemMessage': systemMessage!.toJson(),
      if (infiniteSessions != null) 'infiniteSessions': infiniteSessions,
      'streaming': streaming,
      if (tools.isNotEmpty)
        'tools': tools.map((t) => t.toRegistrationJson()).toList(),
      if (availableTools != null) 'availableTools': availableTools,
      if (excludedTools != null) 'excludedTools': excludedTools,
      if (mcpServers.isNotEmpty)
        'mcpServers': mcpServers.map((s) => s.toJson()).toList(),
      if (customAgents.isNotEmpty)
        'customAgents': customAgents.map((a) => a.toJson()).toList(),
      if (skillDirectories.isNotEmpty) 'skillDirectories': skillDirectories,
      if (provider != null) 'provider': provider!.toJson(),
      if (reasoningEffort != null)
        'reasoningEffort': reasoningEffort!.toJsonValue(),
      if (mode != null) 'mode': mode!.toJsonValue(),
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}

/// Configuration for resuming an existing session.
class ResumeSessionConfig {
  const ResumeSessionConfig({
    required this.sessionId,
    required this.onPermissionRequest,
    this.onUserInputRequest,
    this.tools = const [],
    this.hooks,
  });

  final String sessionId;
  final PermissionHandler onPermissionRequest;
  final UserInputHandler? onUserInputRequest;
  final List<Tool> tools;
  final SessionHooks? hooks;
}

/// Options for sending a message.
class MessageOptions {
  const MessageOptions({
    required this.prompt,
    this.attachments = const [],
    this.mode,
  });

  final String prompt;
  final List<Attachment> attachments;
  final AgentMode? mode;

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

/// MCP server configuration.
class McpServerConfig {
  const McpServerConfig({
    required this.name,
    required this.command,
    this.args = const [],
    this.env,
  });

  final String name;
  final String command;
  final List<String> args;
  final Map<String, String>? env;

  Map<String, dynamic> toJson() => {
        'name': name,
        'command': command,
        if (args.isNotEmpty) 'args': args,
        if (env != null) 'env': env,
      };
}

/// Custom agent configuration.
class CustomAgentConfig {
  const CustomAgentConfig({
    required this.name,
    this.description,
    this.instructions,
    this.tools,
  });

  final String name;
  final String? description;
  final String? instructions;
  final List<String>? tools;

  Map<String, dynamic> toJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (instructions != null) 'instructions': instructions,
        if (tools != null) 'tools': tools,
      };
}

/// BYOK (Bring Your Own Key) provider configuration.
class ProviderConfig {
  const ProviderConfig({
    required this.type,
    required this.apiKey,
    this.baseUrl,
  });

  final String type;
  final String apiKey;
  final String? baseUrl;

  Map<String, dynamic> toJson() => {
        'type': type,
        'apiKey': apiKey,
        if (baseUrl != null) 'baseUrl': baseUrl,
      };
}

/// File/image attachment for a message.
class Attachment {
  const Attachment({
    required this.type,
    this.path,
    this.url,
    this.data,
    this.mimeType,
  });

  final String type;
  final String? path;
  final String? url;
  final String? data;
  final String? mimeType;

  factory Attachment.file(String path) => Attachment(type: 'file', path: path);

  factory Attachment.image({required String data, String? mimeType}) =>
      Attachment(type: 'image', data: data, mimeType: mimeType);

  Map<String, dynamic> toJson() => {
        'type': type,
        if (path != null) 'path': path,
        if (url != null) 'url': url,
        if (data != null) 'data': data,
        if (mimeType != null) 'mimeType': mimeType,
      };
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
  high;

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
  const PermissionRequest({this.data});

  final dynamic data;

  factory PermissionRequest.fromJson(dynamic json) =>
      PermissionRequest(data: json);
}

/// Permission result to send back.
class PermissionResult {
  const PermissionResult({required this.kind});

  final String kind;

  /// Pre-built: approve the permission request.
  static const approved = PermissionResult(kind: 'approved');

  /// Pre-built: deny the permission request.
  static const denied = PermissionResult(
    kind: 'denied-no-approval-rule-and-could-not-request-from-user',
  );

  Map<String, dynamic> toJson() => {'kind': kind};
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
