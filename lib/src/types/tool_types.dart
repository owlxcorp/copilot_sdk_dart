/// Tool definition for registering custom tools with Copilot sessions.
class Tool {
  const Tool({
    required this.name,
    this.description,
    this.parameters,
    required this.handler,
  });

  /// Tool name (e.g., "weather", "search").
  final String name;

  /// Human-readable description of what the tool does.
  final String? description;

  /// JSON Schema for the tool's input parameters.
  final Map<String, dynamic>? parameters;

  /// Handler function invoked when the tool is called.
  final ToolHandler handler;

  /// Converts to JSON for registration with the CLI (excludes handler).
  Map<String, dynamic> toRegistrationJson() => {
        'name': name,
        if (description != null) 'description': description,
        if (parameters != null) 'parameters': parameters,
      };
}

/// Handler function type for tool invocations.
typedef ToolHandler = Future<ToolResult> Function(
  dynamic args,
  ToolInvocation invocation,
);

/// Context provided to tool handlers during invocation.
class ToolInvocation {
  const ToolInvocation({
    required this.sessionId,
    required this.toolCallId,
    required this.toolName,
    required this.arguments,
  });

  final String sessionId;
  final String toolCallId;
  final String toolName;
  final dynamic arguments;
}

/// Result returned from a tool handler.
sealed class ToolResult {
  const ToolResult();

  /// Creates a successful text result.
  factory ToolResult.success(String text) = ToolResultSuccess;

  /// Creates a failure result.
  factory ToolResult.failure({required String error, String? textForLlm}) =
      ToolResultFailure;

  /// Creates a result from a full object.
  factory ToolResult.object({
    required String textResultForLlm,
    required ToolResultType resultType,
    String? error,
    Map<String, dynamic>? toolTelemetry,
  }) = ToolResultObject;

  Map<String, dynamic> toJson();
}

/// A successful tool result.
class ToolResultSuccess extends ToolResult {
  const ToolResultSuccess(this.text);

  final String text;

  @override
  Map<String, dynamic> toJson() => {
        'textResultForLlm': text,
        'resultType': 'success',
        'toolTelemetry': <String, dynamic>{},
      };
}

/// A failed tool result.
class ToolResultFailure extends ToolResult {
  const ToolResultFailure({required this.error, this.textForLlm});

  final String error;
  final String? textForLlm;

  @override
  Map<String, dynamic> toJson() => {
        'textResultForLlm': textForLlm ??
            'Invoking this tool produced an error. '
                'Detailed information is not available.',
        'resultType': 'failure',
        'error': error,
        'toolTelemetry': <String, dynamic>{},
      };
}

/// A full tool result object with all fields.
class ToolResultObject extends ToolResult {
  const ToolResultObject({
    required this.textResultForLlm,
    required this.resultType,
    this.error,
    this.toolTelemetry,
    this.binaryResultsForLlm,
    this.sessionLog,
  });

  final String textResultForLlm;
  final ToolResultType resultType;
  final String? error;
  final Map<String, dynamic>? toolTelemetry;

  /// Binary results (images, files) to include in the LLM context.
  final List<ToolBinaryResult>? binaryResultsForLlm;

  /// Log message to record in the session history.
  final String? sessionLog;

  @override
  Map<String, dynamic> toJson() => {
        'textResultForLlm': textResultForLlm,
        'resultType': resultType.toJsonValue(),
        if (error != null) 'error': error,
        'toolTelemetry': toolTelemetry ?? <String, dynamic>{},
        if (binaryResultsForLlm != null)
          'binaryResultsForLlm':
              binaryResultsForLlm!.map((b) => b.toJson()).toList(),
        if (sessionLog != null) 'sessionLog': sessionLog,
      };
}

/// Binary data result from a tool (images, files, etc.).
class ToolBinaryResult {
  const ToolBinaryResult({
    required this.data,
    required this.mimeType,
    this.type,
    this.description,
  });

  /// Base64-encoded binary data.
  final String data;

  /// MIME type (e.g., 'image/png', 'application/pdf').
  final String mimeType;

  /// Result type identifier.
  final String? type;

  /// Optional description of the binary content.
  final String? description;

  Map<String, dynamic> toJson() => {
        'data': data,
        'mimeType': mimeType,
        if (type != null) 'type': type,
        if (description != null) 'description': description,
      };
}

/// Result type for tool execution.
enum ToolResultType {
  success,
  failure,
  rejected,
  denied;

  String toJsonValue() => name;
}

/// Normalizes any tool handler return value to a [ToolResult].
ToolResult normalizeToolResult(dynamic result) {
  if (result == null) {
    return const ToolResultFailure(error: 'tool returned no result');
  }
  if (result is ToolResult) return result;
  if (result is String) return ToolResultSuccess(result);
  return ToolResultSuccess(result.toString());
}
