import 'dart:async';

import 'session.dart';
import 'transport/json_rpc_connection.dart';
import 'transport/json_rpc_transport.dart';
import 'types/auth_types.dart';
import 'types/client_options.dart';
import 'types/connection_state.dart';
import 'types/session_config.dart';
import 'types/session_event.dart';
import 'types/tool_types.dart';

/// The expected protocol version for the Copilot CLI.
const int sdkProtocolVersion = 2;

/// Client for communicating with the Copilot CLI server.
///
/// ```dart
/// final client = CopilotClient(
///   options: CopilotClientOptions(cliPath: '/usr/local/bin/copilot'),
///   transport: StdioTransport(executable: 'copilot', arguments: ['--headless']),
/// );
/// await client.start();
///
/// final session = await client.createSession(
///   config: SessionConfig(
///     model: 'gpt-4',
///     onPermissionRequest: approveAllPermissions,
///   ),
/// );
/// ```
class CopilotClient {
  CopilotClient({
    required this.options,
    required JsonRpcTransport transport,
  }) : _transport = transport;

  final CopilotClientOptions options;
  final JsonRpcTransport _transport;

  JsonRpcConnection? _connection;
  ConnectionState _connectionState = ConnectionState.disconnected;
  final Map<String, CopilotSession> _sessions = {};

  // Callbacks
  void Function(ConnectionState state)? onConnectionStateChanged;
  void Function(Object error)? onError;

  /// Current connection state.
  ConnectionState get connectionState => _connectionState;

  /// Whether the client is connected.
  bool get isConnected => _connectionState == ConnectionState.connected;

  /// Active sessions.
  Map<String, CopilotSession> get sessions => Map.unmodifiable(_sessions);

  // ── Connection Lifecycle ────────────────────────────────────────────────

  /// Starts the client and establishes a connection to the CLI server.
  Future<void> start() async {
    if (_connectionState == ConnectionState.connected) return;

    _setConnectionState(ConnectionState.connecting);

    try {
      // Start transport (spawns process or connects socket)
      await _startTransport();

      // Create JSON-RPC connection over transport
      _connection = JsonRpcConnection(_transport);
      _connection!.onClose = _handleConnectionClose;

      // Register server→client handlers
      _registerHandlers();

      // Verify protocol compatibility
      await _verifyProtocol();

      _setConnectionState(ConnectionState.connected);
    } catch (e) {
      _setConnectionState(ConnectionState.error);
      rethrow;
    }
  }

  /// Stops the client and closes all sessions.
  Future<void> stop() async {
    // Destroy all sessions
    final sessionsToDestroy = List<CopilotSession>.from(_sessions.values);
    for (final session in sessionsToDestroy) {
      try {
        await session.destroy();
      } catch (_) {
        // Best effort cleanup
      }
    }
    _sessions.clear();

    // Close connection and transport
    await _connection?.close();
    _connection = null;
    await _transport.close();

    _setConnectionState(ConnectionState.disconnected);
  }

  // ── Session Management ─────────────────────────────────────────────────

  /// Creates a new Copilot session.
  Future<CopilotSession> createSession({
    required SessionConfig config,
  }) async {
    _ensureConnected();

    final result = await _connection!.sendRequest(
      'session.create',
      config.toJson(),
      const Duration(seconds: 30),
    );

    final resultMap = result as Map<String, dynamic>;
    final sessionId = resultMap['sessionId'] as String;
    final session = CopilotSession(
      sessionId: sessionId,
      connection: _connection!,
      config: config,
    );

    _sessions[sessionId] = session;
    session.onDestroyed = () => _sessions.remove(sessionId);

    return session;
  }

  /// Resumes an existing session.
  Future<CopilotSession> resumeSession({
    required ResumeSessionConfig config,
  }) async {
    _ensureConnected();

    final result = await _connection!.sendRequest(
      'session.resume',
      {'sessionId': config.sessionId},
      const Duration(seconds: 30),
    );

    final resultMap = result as Map<String, dynamic>;
    final sessionId = resultMap['sessionId'] as String;
    final session = CopilotSession(
      sessionId: sessionId,
      connection: _connection!,
      config: SessionConfig(
        tools: config.tools,
        hooks: config.hooks,
        onPermissionRequest: config.onPermissionRequest,
        onUserInputRequest: config.onUserInputRequest,
      ),
    );

    _sessions[sessionId] = session;
    session.onDestroyed = () => _sessions.remove(sessionId);

    return session;
  }

  /// Lists available sessions.
  Future<List<SessionMetadata>> listSessions({
    SessionListFilter? filter,
  }) async {
    _ensureConnected();

    final result = await _connection!.sendRequest(
      'session.list',
      filter?.toJson() ?? {},
      const Duration(seconds: 10),
    );

    final resultMap = result as Map<String, dynamic>;
    final sessions = resultMap['sessions'] as List<dynamic>;
    return sessions
        .map((s) => SessionMetadata.fromJson(s as Map<String, dynamic>))
        .toList();
  }

  /// Deletes a session by ID.
  Future<void> deleteSession(String sessionId) async {
    _ensureConnected();

    await _connection!.sendRequest(
      'session.delete',
      {'sessionId': sessionId},
      const Duration(seconds: 10),
    );

    _sessions.remove(sessionId);
  }

  // ── Server RPC Methods ─────────────────────────────────────────────────

  /// Pings the CLI server. Returns pong response.
  Future<Map<String, dynamic>> ping() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'ping',
      <String, dynamic>{},
      const Duration(seconds: 5),
    );
    return result as Map<String, dynamic>;
  }

  /// Gets the CLI server status.
  Future<GetStatusResponse> getStatus() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'status.get',
      <String, dynamic>{},
      const Duration(seconds: 5),
    );
    return GetStatusResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Gets the authentication status.
  Future<GetAuthStatusResponse> getAuthStatus() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'auth.getStatus',
      <String, dynamic>{},
      const Duration(seconds: 10),
    );
    return GetAuthStatusResponse.fromJson(result as Map<String, dynamic>);
  }

  /// Lists available models.
  Future<List<ModelInfo>> listModels() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'models.list',
      <String, dynamic>{},
      const Duration(seconds: 10),
    );
    final map = result as Map<String, dynamic>;
    final models = map['models'] as List<dynamic>;
    return models
        .map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
        .toList();
  }

  /// Lists available built-in tools.
  Future<List<ToolInfo>> listTools() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'tools.list',
      <String, dynamic>{},
      const Duration(seconds: 10),
    );
    final map = result as Map<String, dynamic>;
    final tools = map['tools'] as List<dynamic>;
    return tools
        .map((t) => ToolInfo.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// Gets account quota information.
  Future<AccountQuota> getAccountQuota() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'account.getQuota',
      <String, dynamic>{},
      const Duration(seconds: 10),
    );
    return AccountQuota.fromJson(result as Map<String, dynamic>);
  }

  // ── Internal ───────────────────────────────────────────────────────────

  Future<void> _startTransport() async {
    // Check transport type and call appropriate start/connect method.
    // The transport interface is abstract, so we use duck-typing.
    final transport = _transport;
    if (!transport.isOpen) {
      // Try to start/connect the transport. The concrete type
      // should expose start() or connect().
      // For pre-opened transports (e.g., MockTransport), this is skipped.
      throw StateError(
        'Transport is not open. Call start() or connect() '
        'on the transport before creating the client, or use a transport '
        'that auto-opens.',
      );
    }
  }

  void _registerHandlers() {
    final conn = _connection!;

    // Session events (notifications)
    conn.registerNotificationHandler(
      'session.event',
      (dynamic params) => _handleSessionEvent(params),
    );

    // Tool call requests (server → client)
    conn.registerRequestHandler(
      'toolCall.request',
      (dynamic params) => _handleToolCallRequest(params),
    );

    // Permission requests (server → client)
    conn.registerRequestHandler(
      'permission.request',
      (dynamic params) => _handlePermissionRequest(params),
    );

    // User input requests (server → client)
    conn.registerRequestHandler(
      'userInput.request',
      (dynamic params) => _handleUserInputRequest(params),
    );

    // Hook invocations (server → client)
    conn.registerRequestHandler(
      'hooks.invoke',
      (dynamic params) => _handleHookInvoke(params),
    );
  }

  Future<void> _verifyProtocol() async {
    final pong = await _connection!.sendRequest(
      'ping',
      <String, dynamic>{},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    final serverVersion = pong['protocolVersion'] as int?;
    if (serverVersion != null && serverVersion != sdkProtocolVersion) {
      throw StateError(
        'Protocol version mismatch: SDK expects $sdkProtocolVersion, '
        'server reported $serverVersion',
      );
    }
  }

  void _handleSessionEvent(dynamic params) {
    if (params == null || params is! Map<String, dynamic>) return;

    final eventPayload = params['event'];
    final eventJson =
        eventPayload is Map<String, dynamic> ? eventPayload : params;
    if (eventJson['type'] is! String) return;

    SessionEvent event;
    try {
      event = SessionEvent.fromJson(eventJson);
    } catch (error) {
      onError?.call(error);
      return;
    }
    final sessionId =
        (params['sessionId'] ?? eventJson['sessionId']) as String?;
    if (sessionId != null && _sessions.containsKey(sessionId)) {
      _sessions[sessionId]!.handleEvent(event);
      return;
    }

    // `session.start` carries sessionId in event data, so route by embedded ID.
    if (event is SessionStartEvent) {
      _sessions[event.sessionId]?.handleEvent(event);
      return;
    }

    // Surface malformed notifications instead of silently dropping them.
    if (sessionId == null) {
      onError?.call(
        StateError(
            'session.event missing sessionId for event type: ${event.type}'),
      );
    }
  }

  Future<Map<String, dynamic>> _handleToolCallRequest(dynamic params) async {
    if (params == null || params is! Map<String, dynamic>) {
      throw const JsonRpcError(code: -32602, message: 'Missing params');
    }

    final sessionId = params['sessionId'] as String?;
    final toolName = params['toolName'] as String?;
    final toolCallId = params['toolCallId'] as String?;
    final arguments = params['arguments'];

    if (sessionId == null || toolName == null || toolCallId == null) {
      throw const JsonRpcError(
        code: -32602,
        message: 'Missing required fields',
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcError(
        code: -32600,
        message: 'Unknown session: $sessionId',
      );
    }

    final invocation = ToolInvocation(
      sessionId: sessionId,
      toolCallId: toolCallId,
      toolName: toolName,
      arguments: arguments,
    );

    final result =
        await session.handleToolCall(toolName, arguments, invocation);
    return result.toJson();
  }

  Future<Map<String, dynamic>> _handlePermissionRequest(
    dynamic params,
  ) async {
    if (params == null || params is! Map<String, dynamic>) {
      throw const JsonRpcError(code: -32602, message: 'Missing params');
    }

    final sessionId = params['sessionId'] as String?;
    if (sessionId == null) {
      throw const JsonRpcError(code: -32602, message: 'Missing sessionId');
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcError(
        code: -32600,
        message: 'Unknown session: $sessionId',
      );
    }

    final request = PermissionRequest.fromJson(params);
    final invocation = PermissionInvocation(sessionId: sessionId);

    final result =
        await session.config.onPermissionRequest(request, invocation);
    return result.toJson();
  }

  Future<Map<String, dynamic>> _handleUserInputRequest(
    dynamic params,
  ) async {
    if (params == null || params is! Map<String, dynamic>) {
      throw const JsonRpcError(code: -32602, message: 'Missing params');
    }

    final sessionId = params['sessionId'] as String?;
    if (sessionId == null) {
      throw const JsonRpcError(code: -32602, message: 'Missing sessionId');
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcError(
        code: -32600,
        message: 'Unknown session: $sessionId',
      );
    }

    final handler = session.config.onUserInputRequest;
    if (handler == null) {
      throw const JsonRpcError(
        code: -32601,
        message: 'No user input handler registered',
      );
    }

    final request = UserInputRequest.fromJson(params);
    final invocation = UserInputInvocation(sessionId: sessionId);

    final result = await handler(request, invocation);
    return result.toJson();
  }

  Future<Map<String, dynamic>> _handleHookInvoke(dynamic params) async {
    if (params == null || params is! Map<String, dynamic>) {
      throw const JsonRpcError(code: -32602, message: 'Missing params');
    }

    final sessionId = params['sessionId'] as String?;
    final hookType = params['hookType'] as String?;
    final input = params['input'];

    if (sessionId == null || hookType == null) {
      throw const JsonRpcError(
        code: -32602,
        message: 'Missing required fields',
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      throw JsonRpcError(
        code: -32600,
        message: 'Unknown session: $sessionId',
      );
    }

    final hooks = session.config.hooks;
    if (hooks == null) {
      return <String, dynamic>{};
    }

    final result = await hooks.invoke(hookType, input, sessionId);
    if (result == null) return <String, dynamic>{};
    if (result is Map<String, dynamic>) return result;
    return (result as dynamic).toJson() as Map<String, dynamic>;
  }

  void _handleConnectionClose() {
    _setConnectionState(ConnectionState.disconnected);
    // Notify all sessions
    for (final session in _sessions.values) {
      session.handleConnectionClose();
    }
    _sessions.clear();
  }

  void _setConnectionState(ConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }

  void _ensureConnected() {
    if (!isConnected || _connection == null) {
      throw StateError('Client is not connected. Call start() first.');
    }
  }
}
