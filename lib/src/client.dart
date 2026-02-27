import 'dart:async';

import 'session.dart';
import 'transport/json_rpc_connection.dart';
import 'transport/json_rpc_transport.dart';
import 'transport/stdio_transport.dart';
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
/// When no [transport] is provided, the client automatically creates a
/// [StdioTransport] using [CopilotClientOptions.cliPath] and appends the
/// required `--headless --stdio --no-auto-update` flags. Additional CLI
/// arguments (e.g. `--model`) can be passed via [CopilotClientOptions.cliArgs].
///
/// ```dart
/// // Minimal — spawns CLI automatically
/// final client = CopilotClient(
///   options: CopilotClientOptions(cliPath: '/usr/local/bin/copilot'),
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
  /// Creates a new client.
  ///
  /// If [transport] is omitted, a [StdioTransport] is created automatically
  /// from [options] with `--headless --stdio --no-auto-update` appended.
  /// Use [CopilotClientOptions.cliArgs] for additional flags like `--model`.
  ///
  /// If [transport] is provided, it is used as-is and the caller is
  /// responsible for configuring it with the correct CLI arguments.
  CopilotClient({
    CopilotClientOptions options = const CopilotClientOptions(),
    JsonRpcTransport? transport,
  })  : options = options,
        _transport = transport;

  final CopilotClientOptions options;
  JsonRpcTransport? _transport;

  JsonRpcConnection? _connection;
  ConnectionState _connectionState = ConnectionState.disconnected;
  final Map<String, CopilotSession> _sessions = {};
  bool _forceStopping = false;

  // Callbacks
  void Function(ConnectionState state)? onConnectionStateChanged;
  void Function(Object error)? onError;

  // Lifecycle event handlers
  final List<void Function(SessionLifecycleEvent)> _lifecycleHandlers = [];
  final Map<SessionLifecycleEventType,
      List<void Function(SessionLifecycleEvent)>> _typedLifecycleHandlers = {};

  // Models cache with lock to prevent concurrent fetches
  List<ModelInfo>? _modelsCache;
  Completer<void>? _modelsCacheLock;

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
      _connection = JsonRpcConnection(_transport!, log: options.log);
      _connection!.onClose = _handleConnectionClose;
      _connection!.onError = (error) {
        options.log?.call('Transport error: $error');
        onError?.call(error);
      };

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
  ///
  /// Sessions are destroyed with up to 3 retries and exponential backoff.
  /// Returns a list of errors encountered during cleanup.
  Future<List<Exception>> stop() async {
    _forceStopping = true;
    final errors = <Exception>[];

    // Destroy all sessions with retry logic (direct RPC, bypassing
    // session.destroy()'s idempotency guard to allow real retries).
    final sessionsToDestroy = List<CopilotSession>.from(_sessions.values);
    for (final session in sessionsToDestroy) {
      Exception? lastError;

      for (var attempt = 1; attempt <= 3; attempt++) {
        try {
          await _connection?.sendRequest(
            'session.destroy',
            {'sessionId': session.sessionId},
            const Duration(seconds: 10),
          );
          lastError = null;
          break;
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (attempt < 3) {
            // Exponential backoff: 100ms, 200ms
            await Future<void>.delayed(
              Duration(milliseconds: 100 * (1 << (attempt - 1))),
            );
          }
        }
      }

      // Always clean up the session locally
      session.handleConnectionClose();

      if (lastError != null) {
        errors.add(Exception(
          'Failed to destroy session ${session.sessionId} after 3 attempts: '
          '$lastError',
        ));
      }
    }
    _sessions.clear();
    _modelsCache = null;

    // Close connection and transport
    try {
      await _connection?.close();
    } catch (e) {
      errors.add(
          e is Exception ? e : Exception('Failed to close connection: $e'));
    }
    _connection = null;

    try {
      await _transport?.close();
    } catch (e) {
      errors
          .add(e is Exception ? e : Exception('Failed to close transport: $e'));
    }

    _setConnectionState(ConnectionState.disconnected);
    _forceStopping = false;
    return errors;
  }

  /// Force-stops the client immediately without graceful session cleanup.
  ///
  /// Unlike [stop], this does not attempt to destroy sessions via RPC.
  /// It clears sessions, kills the connection, and closes the transport.
  Future<void> forceStop() async {
    _forceStopping = true;
    _sessions.clear();
    _modelsCache = null;

    await _connection?.close();
    _connection = null;
    await _transport?.close();

    _setConnectionState(ConnectionState.disconnected);
  }

  // ── Session Management ─────────────────────────────────────────────────

  /// Creates a new Copilot session.
  Future<CopilotSession> createSession({
    required SessionConfig config,
  }) async {
    await _autoStartIfNeeded();

    // Build payload with merged tools and sdkProtocolVersion
    final payload = config.toJson();
    if (options.tools.isNotEmpty) {
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      // Client tools first (matching upstream dedup order)
      for (final t in options.tools) {
        if (seen.add(t.name)) merged.add(t.toRegistrationJson());
      }
      for (final t in config.tools) {
        if (seen.add(t.name)) merged.add(t.toRegistrationJson());
      }
      payload['tools'] = merged;
    }

    final result = await _connection!.sendRequest(
      'session.create',
      payload,
      const Duration(seconds: 30),
    );

    final resultMap = result as Map<String, dynamic>;
    final sessionId = resultMap['sessionId'] as String;
    final workspacePath = resultMap['workspacePath'] as String?;

    // Resolve effective handlers (session config > client options)
    final effectiveConfig = SessionConfig(
      sessionId: config.sessionId,
      clientName: config.clientName,
      model: config.model,
      systemMessage: config.systemMessage,
      infiniteSessions: config.infiniteSessions,
      streaming: config.streaming,
      tools: config.tools,
      availableTools: config.availableTools,
      excludedTools: config.excludedTools,
      mcpServers: config.mcpServers,
      customAgents: config.customAgents,
      skillDirectories: config.skillDirectories,
      disabledSkills: config.disabledSkills,
      hooks: config.hooks ?? options.hooks,
      provider: config.provider,
      reasoningEffort: config.reasoningEffort,
      mode: config.mode,
      attachments: config.attachments,
      configDir: config.configDir,
      workingDirectory: config.workingDirectory,
      onPermissionRequest: config.onPermissionRequest,
      onUserInputRequest:
          config.onUserInputRequest ?? options.onUserInputRequest,
    );

    final session = CopilotSession(
      sessionId: sessionId,
      connection: _connection!,
      config: effectiveConfig,
      workspacePath: workspacePath,
    );

    _sessions[sessionId] = session;
    session.onDestroyed = () => _sessions.remove(sessionId);

    return session;
  }

  /// Resumes an existing session.
  Future<CopilotSession> resumeSession({
    required ResumeSessionConfig config,
  }) async {
    await _autoStartIfNeeded();

    // Build payload with merged tools and sdkProtocolVersion
    final payload = config.toJson();
    if (options.tools.isNotEmpty) {
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final t in options.tools) {
        if (seen.add(t.name)) merged.add(t.toRegistrationJson());
      }
      for (final t in config.tools) {
        if (seen.add(t.name)) merged.add(t.toRegistrationJson());
      }
      payload['tools'] = merged;
    }

    final result = await _connection!.sendRequest(
      'session.resume',
      payload,
      const Duration(seconds: 30),
    );

    final resultMap = result as Map<String, dynamic>;
    final sessionId = resultMap['sessionId'] as String;
    final workspacePath = resultMap['workspacePath'] as String?;
    final session = CopilotSession(
      sessionId: sessionId,
      connection: _connection!,
      config: SessionConfig(
        tools: config.tools,
        hooks: config.hooks ?? options.hooks,
        model: config.model,
        systemMessage: config.systemMessage,
        provider: config.provider,
        reasoningEffort: config.reasoningEffort,
        mcpServers: config.mcpServers,
        customAgents: config.customAgents,
        onPermissionRequest: config.onPermissionRequest,
        onUserInputRequest:
            config.onUserInputRequest ?? options.onUserInputRequest,
      ),
      workspacePath: workspacePath,
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
      <String, dynamic>{if (filter != null) 'filter': filter.toJson()},
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

    final result = await _connection!.sendRequest(
      'session.delete',
      {'sessionId': sessionId},
      const Duration(seconds: 10),
    ) as Map<String, dynamic>;

    final success = result['success'] as bool?;
    if (success == false) {
      final error = result['error'] as String? ?? 'Unknown error';
      throw StateError(
        'Failed to delete session $sessionId: $error',
      );
    }

    _sessions.remove(sessionId);
  }

  // ── Server RPC Methods ─────────────────────────────────────────────────

  /// Pings the CLI server. Returns pong response.
  Future<Map<String, dynamic>> ping({String? message}) async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'ping',
      <String, dynamic>{if (message != null) 'message': message},
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
  ///
  /// Results are cached after the first call. The cache is cleared on [stop]
  /// or [forceStop]. Concurrent calls share the same fetch (lock-based).
  /// Set [forceRefresh] to `true` to bypass the cache.
  Future<List<ModelInfo>> listModels({bool forceRefresh = false}) async {
    _ensureConnected();

    if (forceRefresh) {
      _modelsCache = null;
    }

    // Wait for any in-flight fetch to complete
    while (_modelsCacheLock != null) {
      await _modelsCacheLock!.future;
    }

    // Return cached copy if available
    if (_modelsCache != null) {
      return List.of(_modelsCache!);
    }

    // Acquire lock and fetch
    final lock = Completer<void>();
    _modelsCacheLock = lock;

    try {
      final result = await _connection!.sendRequest(
        'models.list',
        <String, dynamic>{},
        const Duration(seconds: 10),
      );
      final map = result as Map<String, dynamic>;
      final models = (map['models'] as List<dynamic>)
          .map((m) => ModelInfo.fromJson(m as Map<String, dynamic>))
          .toList();
      _modelsCache = models;
      return List.of(models);
    } finally {
      _modelsCacheLock = null;
      lock.complete();
    }
  }

  /// Force-refreshes the models cache and returns the updated list.
  Future<List<ModelInfo>> refreshModelsCache() async {
    _modelsCache = null;
    return listModels();
  }

  /// Lists available built-in tools.
  ///
  /// When [model] is provided, the returned list reflects model-specific
  /// tool overrides.
  Future<List<ToolInfo>> listTools({String? model}) async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'tools.list',
      <String, dynamic>{
        if (model != null) 'model': model,
      },
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

  /// Gets the last session ID.
  Future<String?> getLastSessionId() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'session.getLastId',
      <String, dynamic>{},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    return result['sessionId'] as String?;
  }

  /// Gets the foreground session ID and workspace path.
  Future<ForegroundSessionInfo> getForegroundSessionId() async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'session.getForeground',
      <String, dynamic>{},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    return ForegroundSessionInfo.fromJson(result);
  }

  /// Sets the foreground session.
  ///
  /// Throws if the server reports failure.
  Future<void> setForegroundSessionId(String sessionId) async {
    _ensureConnected();
    final result = await _connection!.sendRequest(
      'session.setForeground',
      {'sessionId': sessionId},
      const Duration(seconds: 5),
    );
    final map = result as Map<String, dynamic>;
    if (map['success'] != true) {
      final error =
          map['error'] as String? ?? 'Failed to set foreground session';
      throw Exception(error);
    }
  }

  // ── Lifecycle Event Subscription ─────────────────────────────────────

  /// Subscribe to all session lifecycle events. Returns an unsubscribe fn.
  void Function() onLifecycleEvent(
    void Function(SessionLifecycleEvent event) handler, [
    SessionLifecycleEventType? type,
  ]) {
    if (type != null) {
      final list = _typedLifecycleHandlers.putIfAbsent(type, () => []);
      list.add(handler);
      return () => list.remove(handler);
    }
    _lifecycleHandlers.add(handler);
    return () => _lifecycleHandlers.remove(handler);
  }

  // ── Internal ───────────────────────────────────────────────────────────

  Future<void> _startTransport() async {
    // If a transport was injected and is already open, use it as-is.
    if (_transport != null && _transport!.isOpen) return;

    // If no transport was provided, build one from options.
    if (_transport == null) {
      _transport = _buildTransport();
    }

    // Start the transport (spawns the CLI process for StdioTransport).
    final transport = _transport!;
    if (transport is StdioTransport) {
      await transport.start();
    } else if (!transport.isOpen) {
      throw StateError(
        'Transport is not open. Call start() on the transport before '
        'creating the client, or omit transport to auto-create one.',
      );
    }
  }

  /// Builds a [StdioTransport] from [options], adding required CLI flags.
  ///
  /// The flags `--headless`, `--stdio`, `--no-auto-update` are always
  /// appended (matching the upstream Node.js SDK behavior).
  /// [CopilotClientOptions.cliArgs] are prepended for user-specified flags.
  StdioTransport _buildTransport() {
    final executable = options.cliPath ?? 'copilot';
    final args = <String>[
      ...options.cliArgs,
      '--headless',
      '--no-auto-update',
    ];

    if (options.useStdio) {
      args.add('--stdio');
    }

    final logLevel = options.logLevel;
    if (logLevel != null) {
      args.addAll(['--log-level', logLevel.toJsonValue()]);
    }

    if (options.githubToken != null) {
      args.add('--auth-token-env');
      args.add('COPILOT_SDK_AUTH_TOKEN');
    }

    if (options.useLoggedInUser == false) {
      args.add('--no-auto-login');
    }

    // Merge env — add auth token if provided
    Map<String, String>? env = options.env;
    if (options.githubToken != null) {
      env = {...?env, 'COPILOT_SDK_AUTH_TOKEN': options.githubToken!};
    }

    return StdioTransport(
      executable: executable,
      arguments: args,
      workingDirectory: options.cwd,
      environment: env,
    );
  }

  void _registerHandlers() {
    final conn = _connection!;

    // Session events (notifications)
    conn.registerNotificationHandler(
      'session.event',
      (dynamic params) => _handleSessionEvent(params),
    );

    // Tool call requests (server → client)
    // The CLI sends tool calls using the 'tool.call' method.
    conn.registerRequestHandler(
      'tool.call',
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

    // Session lifecycle events (server → client)
    conn.registerNotificationHandler(
      'session.lifecycle',
      (dynamic params) => _handleLifecycleEvent(params),
    );
  }

  Future<void> _verifyProtocol() async {
    final pong = await _connection!.sendRequest(
      'ping',
      <String, dynamic>{},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    final serverVersion = pong['protocolVersion'] as int?;
    if (serverVersion == null) {
      throw StateError(
        'Protocol version mismatch: SDK expects $sdkProtocolVersion, '
        'but server does not report a protocol version. '
        'Please update your server to ensure compatibility.',
      );
    }
    if (serverVersion != sdkProtocolVersion) {
      throw StateError(
        'Protocol version mismatch: SDK expects $sdkProtocolVersion, '
        'server reported $serverVersion. '
        'Please update your SDK or server to ensure compatibility.',
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

    try {
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
    } catch (error) {
      // Session routing/dispatch errors must not kill the transport.
      onError?.call(error);
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

    options.log?.call(
        'SDK: tool.call → $toolName (session=$sessionId, callId=$toolCallId)');

    if (sessionId == null || toolName == null || toolCallId == null) {
      throw const JsonRpcError(
        code: -32602,
        message: 'Missing required fields',
      );
    }

    final session = _sessions[sessionId];
    if (session == null) {
      options.log?.call(
          'SDK: tool.call FAILED → session $sessionId not found, have: ${_sessions.keys.join(', ')}');
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

    final result = await session.handleToolCall(
      toolName,
      arguments,
      invocation,
      fallbackTools: options.tools,
    );
    options.log?.call(
        'SDK: tool.call DONE → $toolName result=${result is ToolResultSuccess ? 'success' : 'failure'}');
    // CLI expects {"result": {toolResult}} envelope (matches Go SDK toolCallResponse)
    return {'result': result.toJson()};
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

    try {
      final result =
          await session.effectivePermissionHandler(request, invocation);
      // CLI expects {"result": {permissionResult}} envelope
      return {'result': result.toJson()};
    } catch (_) {
      // If permission handler fails, deny the permission (matches upstream)
      return {
        'result': {
          'kind': 'denied-no-approval-rule-and-could-not-request-from-user',
        },
      };
    }
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

    final handler = session.effectiveUserInputHandler;
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

    final hooks = session.effectiveHooks;
    if (hooks == null) {
      return <String, dynamic>{};
    }

    try {
      final result = await hooks.invoke(hookType, input, sessionId);
      if (result == null) return <String, dynamic>{};
      // CLI expects {output: hookResult} envelope (matches upstream)
      final output = result is Map<String, dynamic>
          ? result
          : (result as dynamic).toJson() as Map<String, dynamic>;
      return {'output': output};
    } catch (_) {
      // Hook failed — return empty (matches upstream behavior)
      return <String, dynamic>{};
    }
  }

  void _handleLifecycleEvent(dynamic params) {
    if (params == null || params is! Map<String, dynamic>) return;
    try {
      final event = SessionLifecycleEvent.fromJson(params);
      for (final handler in List.of(_lifecycleHandlers)) {
        try {
          handler(event);
        } catch (_) {}
      }
      final typed = _typedLifecycleHandlers[event.type];
      if (typed != null) {
        for (final handler in List.of(typed)) {
          try {
            handler(event);
          } catch (_) {}
        }
      }
    } catch (e) {
      onError?.call(e);
    }
  }

  void _handleConnectionClose() {
    final shouldRestart =
        options.autoRestart && !_forceStopping && _transport is StdioTransport;
    _setConnectionState(ConnectionState.disconnected);
    // Notify all sessions
    for (final session in _sessions.values) {
      session.handleConnectionClose();
    }
    _sessions.clear();

    // Auto-restart only for stdio transport (we own the process)
    if (shouldRestart) {
      _reconnect();
    }
  }

  /// Attempt to reconnect to the server.
  Future<void> _reconnect() async {
    try {
      await stop();
      _forceStopping = false;
      await start();
    } catch (_) {
      // Reconnection failed — remain disconnected
    }
  }

  void _setConnectionState(ConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    onConnectionStateChanged?.call(state);
  }

  /// Auto-starts the client if [CopilotClientOptions.autoStart] is enabled
  /// and the client is not yet connected.
  Future<void> _autoStartIfNeeded() async {
    if (isConnected && _connection != null) return;
    if (options.autoStart) {
      await start();
    } else {
      _ensureConnected();
    }
  }

  void _ensureConnected() {
    if (!isConnected || _connection == null) {
      throw StateError('Client is not connected. Call start() first.');
    }
  }
}
