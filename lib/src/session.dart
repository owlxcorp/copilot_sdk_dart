import 'dart:async';

import 'transport/json_rpc_connection.dart';
import 'types/session_config.dart';
import 'types/session_event.dart';
import 'types/tool_types.dart';

/// A Copilot agent session.
///
/// Sessions are created via [CopilotClient.createSession] or
/// [CopilotClient.resumeSession].
///
/// ```dart
/// final session = await client.createSession(
///   config: SessionConfig(onPermissionRequest: approveAllPermissions),
/// );
///
/// // Event-driven
/// session.on((event) {
///   switch (event) {
///     case AssistantMessageEvent(:final content):
///       stdout.write(content);
///     case SessionIdleEvent():
///       print('\n--- Done ---');
///   }
/// });
///
/// // Send a message
/// await session.send('Hello, Copilot!');
///
/// // Or wait for completion
/// final reply = await session.sendAndWait('What is 2+2?');
/// print(reply?.content);
/// ```
class CopilotSession {
  CopilotSession({
    required this.sessionId,
    required JsonRpcConnection connection,
    required this.config,
  }) : _connection = connection;

  /// The unique session ID.
  final String sessionId;

  /// Session configuration.
  final SessionConfig config;

  final JsonRpcConnection _connection;

  // Event handlers
  final List<void Function(SessionEvent)> _eventHandlers = [];
  final List<_OnceHandler> _onceHandlers = [];

  // Tool registry (session-local)
  final Map<String, Tool> _tools = {};

  // Event stream
  StreamController<SessionEvent>? _eventStreamController;

  // Lifecycle
  bool _destroyed = false;
  Future<void>? _destroyFuture;

  /// Called when the session is destroyed (used by CopilotClient).
  void Function()? onDestroyed;

  /// Whether the session has been destroyed.
  bool get isDestroyed => _destroyed;

  /// A broadcast stream of all session events.
  Stream<SessionEvent> get events {
    _eventStreamController ??= StreamController<SessionEvent>.broadcast();
    return _eventStreamController!.stream;
  }

  // ── Event Handling ─────────────────────────────────────────────────────

  /// Register a handler for all session events. Returns an unsubscribe fn.
  void Function() on(void Function(SessionEvent event) handler) {
    _eventHandlers.add(handler);
    return () => _eventHandlers.remove(handler);
  }

  /// Register a typed handler. Only called for events of type [T].
  void Function() onType<T extends SessionEvent>(
    void Function(T event) handler,
  ) {
    void wrapper(SessionEvent event) {
      if (event is T) handler(event);
    }

    _eventHandlers.add(wrapper);
    return () => _eventHandlers.remove(wrapper);
  }

  /// Register a one-shot handler. Automatically removed after first call.
  void Function() once(void Function(SessionEvent event) handler) {
    final onceHandler = _OnceHandler(handler);
    _onceHandlers.add(onceHandler);
    return () => _onceHandlers.remove(onceHandler);
  }

  /// Internal: dispatch an event to all handlers.
  void handleEvent(SessionEvent event) {
    if (_destroyed) return;

    // Notify event stream
    _eventStreamController?.add(event);

    // Notify persistent handlers
    for (final handler in List.of(_eventHandlers)) {
      handler(event);
    }

    // Notify one-shot handlers
    final toRemove = <_OnceHandler>[];
    for (final once in List.of(_onceHandlers)) {
      once.handler(event);
      toRemove.add(once);
    }
    _onceHandlers.removeWhere(toRemove.contains);
  }

  /// Internal: handle connection close.
  void handleConnectionClose() {
    _destroyed = true;
    _eventStreamController?.close();
    _eventStreamController = null;
  }

  // ── Tool Management ────────────────────────────────────────────────────

  /// Adds a tool to this session.
  void addTool(Tool tool) {
    _tools[tool.name] = tool;
  }

  /// Removes a tool by name.
  void removeTool(String name) {
    _tools.remove(name);
  }

  /// Internal: handle a tool call from the CLI.
  Future<ToolResult> handleToolCall(
    String toolName,
    dynamic arguments,
    ToolInvocation invocation,
  ) async {
    // Check session-local tools first, then config tools
    final tool = _tools[toolName] ??
        config.tools.cast<Tool?>().firstWhere(
              (t) => t!.name == toolName,
              orElse: () => null,
            );

    if (tool == null) {
      return ToolResult.failure(
        error: 'Unknown tool: $toolName',
        textForLlm: 'Tool "$toolName" is not registered in this session.',
      );
    }

    try {
      return await tool.handler(arguments, invocation);
    } catch (e) {
      return ToolResult.failure(
        error: e.toString(),
        textForLlm: 'Tool "$toolName" threw an error: $e',
      );
    }
  }

  // ── Messaging ──────────────────────────────────────────────────────────

  /// Sends a message to the session. Returns the message ID.
  Future<String> send(
    String prompt, {
    List<Attachment> attachments = const [],
    AgentMode? mode,
  }) async {
    _ensureAlive();

    final params = <String, dynamic>{
      'sessionId': sessionId,
      'prompt': prompt,
      if (attachments.isNotEmpty)
        'attachments': attachments.map((a) => a.toJson()).toList(),
      if (mode != null) 'mode': mode.toJsonValue(),
    };

    final result = await _connection.sendRequest(
      'session.send',
      params,
      const Duration(seconds: 30),
    ) as Map<String, dynamic>;

    return result['messageId'] as String;
  }

  /// Sends a message and waits for the assistant's complete reply.
  ///
  /// Returns the concatenated assistant message content, or null on timeout.
  Future<AssistantReply?> sendAndWait(
    String prompt, {
    List<Attachment> attachments = const [],
    AgentMode? mode,
    Duration timeout = const Duration(minutes: 5),
  }) async {
    _ensureAlive();

    final completer = Completer<AssistantReply?>();
    final buffer = StringBuffer();
    String? messageId;
    var sendCompleted = false;
    var idleReceived = false;

    void completeIfReady() {
      if (!sendCompleted || !idleReceived || completer.isCompleted) return;
      completer.complete(
        buffer.isEmpty
            ? null
            : AssistantReply(
                content: buffer.toString(),
                messageId: messageId,
              ),
      );
    }

    // Listen for assistant message events and session idle
    final unsub = on((event) {
      switch (event) {
        case AssistantMessageEvent(:final content):
          buffer.write(content);
        case AssistantMessageDeltaEvent(:final deltaContent):
          buffer.write(deltaContent);
        case SessionIdleEvent():
          idleReceived = true;
          completeIfReady();
        case SessionErrorEvent(:final message):
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('Session error: $message'),
            );
          }
        default:
          break;
      }
    });

    try {
      messageId = await send(
        prompt,
        attachments: attachments,
        mode: mode,
      );
      sendCompleted = true;
      completeIfReady();

      // Wait with timeout
      return await completer.future.timeout(
        timeout,
        onTimeout: () => null,
      );
    } finally {
      unsub();
    }
  }

  // ── Session RPC Methods ────────────────────────────────────────────────

  /// Gets the current messages in this session.
  Future<List<SessionEvent>> getMessages() async {
    _ensureAlive();

    final result = await _connection.sendRequest(
      'session.getMessages',
      {'sessionId': sessionId},
      const Duration(seconds: 10),
    ) as Map<String, dynamic>;

    final events = result['events'] as List<dynamic>;
    return events
        .map((e) => SessionEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Aborts the current operation in this session.
  Future<void> abort() async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.abort',
      {'sessionId': sessionId},
      const Duration(seconds: 10),
    );
  }

  /// Destroys this session.
  Future<void> destroy() {
    if (_destroyed) return Future<void>.value();
    final inFlight = _destroyFuture;
    if (inFlight != null) return inFlight;
    // Assign _destroyFuture atomically before any async work begins so that
    // a second synchronous caller sees a non-null future immediately.
    final completer = Completer<void>();
    _destroyFuture = completer.future;
    _destroyImpl().then(
      (_) => completer.complete(),
      onError: completer.completeError,
    );
    return completer.future;
  }

  Future<void> _destroyImpl() async {
    _destroyed = true;
    try {
      await _connection.sendRequest(
        'session.destroy',
        {'sessionId': sessionId},
        const Duration(seconds: 10),
      );
    } finally {
      await _eventStreamController?.close();
      _eventStreamController = null;
      _eventHandlers.clear();
      _onceHandlers.clear();
      _tools.clear();
      onDestroyed?.call();
    }
  }

  // ── Model RPC ──────────────────────────────────────────────────────────

  /// Gets the current model for this session.
  Future<String> getCurrentModel() async {
    _ensureAlive();
    final result = await _connection.sendRequest(
      'session.model.getCurrent',
      {'sessionId': sessionId},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    return result['modelId'] as String;
  }

  /// Switches the model for this session.
  Future<void> switchModel(String modelId) async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.model.switchTo',
      {'sessionId': sessionId, 'modelId': modelId},
      const Duration(seconds: 10),
    );
  }

  // ── Mode RPC ───────────────────────────────────────────────────────────

  /// Gets the current agent mode.
  Future<AgentMode> getMode() async {
    _ensureAlive();
    final result = await _connection.sendRequest(
      'session.mode.get',
      {'sessionId': sessionId},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    return AgentMode.fromJson(result['mode'] as String);
  }

  /// Sets the agent mode.
  Future<void> setMode(AgentMode mode) async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.mode.set',
      {'sessionId': sessionId, 'mode': mode.toJsonValue()},
      const Duration(seconds: 5),
    );
  }

  // ── Plan RPC ───────────────────────────────────────────────────────────

  /// Reads the current plan.
  Future<String?> readPlan() async {
    _ensureAlive();
    final result = await _connection.sendRequest(
      'session.plan.read',
      {'sessionId': sessionId},
      const Duration(seconds: 5),
    ) as Map<String, dynamic>;
    return result['plan'] as String?;
  }

  /// Updates the plan.
  Future<void> updatePlan(String content) async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.plan.update',
      {'sessionId': sessionId, 'content': content},
      const Duration(seconds: 5),
    );
  }

  /// Deletes the plan.
  Future<void> deletePlan() async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.plan.delete',
      {'sessionId': sessionId},
      const Duration(seconds: 5),
    );
  }

  // ── Workspace RPC ──────────────────────────────────────────────────────

  /// Lists files in the workspace.
  Future<List<String>> listWorkspaceFiles() async {
    _ensureAlive();
    final result = await _connection.sendRequest(
      'session.workspace.listFiles',
      {'sessionId': sessionId},
      const Duration(seconds: 10),
    ) as Map<String, dynamic>;
    return (result['files'] as List<dynamic>).cast<String>();
  }

  /// Reads a file from the workspace.
  Future<String> readWorkspaceFile(String path) async {
    _ensureAlive();
    final result = await _connection.sendRequest(
      'session.workspace.readFile',
      {'sessionId': sessionId, 'path': path},
      const Duration(seconds: 10),
    ) as Map<String, dynamic>;
    return result['content'] as String;
  }

  /// Creates a file in the workspace.
  Future<void> createWorkspaceFile(String path, String content) async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.workspace.createFile',
      {'sessionId': sessionId, 'path': path, 'content': content},
      const Duration(seconds: 10),
    );
  }

  // ── Fleet RPC ──────────────────────────────────────────────────────────

  /// Starts fleet mode (spawns sub-agents for parallel execution).
  Future<void> startFleet({String? prompt}) async {
    _ensureAlive();
    await _connection.sendRequest(
      'session.fleet.start',
      {
        'sessionId': sessionId,
        if (prompt != null) 'prompt': prompt,
      },
      const Duration(seconds: 30),
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────

  void _ensureAlive() {
    if (_destroyed) {
      throw StateError('Session has been destroyed');
    }
  }
}

/// Represents a complete assistant reply.
class AssistantReply {
  const AssistantReply({
    required this.content,
    this.messageId,
  });

  final String content;
  final String? messageId;

  @override
  String toString() => content;
}

class _OnceHandler {
  _OnceHandler(this.handler);
  final void Function(SessionEvent) handler;
}
