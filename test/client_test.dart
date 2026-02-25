import 'dart:async';

import 'package:copilot_sdk_dart/src/client.dart';
import 'package:copilot_sdk_dart/src/types/auth_types.dart';
import 'package:copilot_sdk_dart/src/types/client_options.dart';
import 'package:copilot_sdk_dart/src/types/connection_state.dart';
import 'package:copilot_sdk_dart/src/types/hooks.dart';
import 'package:copilot_sdk_dart/src/types/session_config.dart';
import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:copilot_sdk_dart/src/types/tool_types.dart';
import 'package:test/test.dart';

import 'helpers/fake_server.dart';

void main() {
  late FakeServer server;
  late CopilotClient client;

  setUp(() {
    server = FakeServer();
    client = CopilotClient(
      options: const CopilotClientOptions(),
      transport: server.clientTransport,
    );
  });

  tearDown(() async {
    try {
      await client.stop();
    } catch (_) {}
    await server.close();
  });

  // ── Connection Lifecycle ──────────────────────────────────────────────

  group('Connection Lifecycle', () {
    test('starts and transitions to connected state', () async {
      expect(client.connectionState, ConnectionState.disconnected);

      await client.start();

      expect(client.connectionState, ConnectionState.connected);
      expect(client.isConnected, isTrue);
    });

    test('start() is idempotent when already connected', () async {
      await client.start();
      await client.start(); // should not throw

      expect(client.isConnected, isTrue);
    });

    test('notifies onConnectionStateChanged during start', () async {
      final states = <ConnectionState>[];
      client.onConnectionStateChanged = (s) => states.add(s);

      await client.start();

      expect(states, [ConnectionState.connecting, ConnectionState.connected]);
    });

    test('stop() disconnects cleanly', () async {
      await client.start();
      await client.stop();

      expect(client.connectionState, ConnectionState.disconnected);
      expect(client.isConnected, isFalse);
    });

    test('notifies onConnectionStateChanged during stop', () async {
      await client.start();

      final states = <ConnectionState>[];
      client.onConnectionStateChanged = (s) => states.add(s);

      await client.stop();

      expect(states, [ConnectionState.disconnected]);
    });

    test('start() fails with error state on protocol mismatch', () async {
      server.overrideHandler('ping', (params) async {
        return {'protocolVersion': 999};
      });

      final states = <ConnectionState>[];
      client.onConnectionStateChanged = (s) => states.add(s);

      expect(
        () => client.start(),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Protocol version mismatch'),
        )),
      );
      // Wait for the error state
      await Future<void>.delayed(Duration.zero);

      expect(states, contains(ConnectionState.error));
    });

    test('clears sessions on stop', () async {
      await client.start();
      await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(client.sessions, isNotEmpty);

      await client.stop();

      expect(client.sessions, isEmpty);
    });
  });

  // ── Session Management ────────────────────────────────────────────────

  group('Session Management', () {
    setUp(() async {
      await client.start();
    });

    test('createSession returns a session with valid ID', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(session.sessionId, startsWith('fake-session-'));
      expect(client.sessions.containsKey(session.sessionId), isTrue);
    });

    test('createSession forwards config model', () async {
      final session = await client.createSession(
        config: SessionConfig(
          model: 'gpt-4',
          onPermissionRequest: approveAllPermissions,
        ),
      );

      expect(session.config.model, 'gpt-4');
    });

    test('createSession increments session IDs', () async {
      final s1 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final s2 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(s1.sessionId, isNot(equals(s2.sessionId)));
    });

    test('resumeSession returns session for known ID', () async {
      // First create a session on the server side
      final created = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      // Resume it
      final resumed = await client.resumeSession(
        config: ResumeSessionConfig(
          sessionId: created.sessionId,
          onPermissionRequest: approveAllPermissions,
        ),
      );

      expect(resumed.sessionId, created.sessionId);
    });

    test('resumeSession fails for unknown session', () async {
      expect(
        () => client.resumeSession(
          config: ResumeSessionConfig(
            sessionId: 'nonexistent',
            onPermissionRequest: approveAllPermissions,
          ),
        ),
        throwsA(anything),
      );
    });

    test('listSessions returns server sessions', () async {
      await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final sessions = await client.listSessions();

      expect(sessions.length, 2);
      expect(sessions[0], isA<SessionMetadata>());
      expect(sessions[0].sessionId, startsWith('fake-session-'));
    });

    test('listSessions with filter passes params', () async {
      final sessions = await client.listSessions(
        filter: const SessionListFilter(repository: 'owner/repo'),
      );

      // Server returns whatever it has; we just verify no error
      expect(sessions, isA<List<SessionMetadata>>());
    });

    test('deleteSession removes from both client and server', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      await client.deleteSession(session.sessionId);

      expect(client.sessions.containsKey(session.sessionId), isFalse);
    });

    test('session.destroy removes session from client map', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final sid = session.sessionId;

      await session.destroy();

      expect(client.sessions.containsKey(sid), isFalse);
    });
  });

  // ── Server RPC Methods ────────────────────────────────────────────────

  group('Server RPC Methods', () {
    setUp(() async {
      await client.start();
    });

    test('ping returns protocol version', () async {
      final result = await client.ping();

      expect(result['protocolVersion'], 2);
    });

    test('getStatus returns version and protocol', () async {
      final status = await client.getStatus();

      expect(status, isA<GetStatusResponse>());
      expect(status.version, '1.0.0-fake');
      expect(status.protocolVersion, 2);
    });

    test('getAuthStatus returns auth info', () async {
      final auth = await client.getAuthStatus();

      expect(auth, isA<GetAuthStatusResponse>());
      expect(auth.isAuthenticated, isTrue);
      expect(auth.authType, 'oauth');
      expect(auth.host, 'github.com');
      expect(auth.login, 'testuser');
    });

    test('listModels returns model list', () async {
      final models = await client.listModels();

      expect(models, hasLength(2));
      expect(models[0].id, 'gpt-4');
      expect(models[0].name, 'GPT-4');
      expect(models[0].capabilities.supportsVision, isTrue);
      expect(models[1].id, 'claude-sonnet');
      expect(models[1].capabilities.maxContextWindowTokens, 200000);
    });

    test('listTools returns tool list', () async {
      final tools = await client.listTools();

      expect(tools, hasLength(2));
      expect(tools[0].name, 'bash');
      expect(tools[0].description, 'Run bash commands');
      expect(tools[1].name, 'read_file');
    });

    test('getAccountQuota returns quota info', () async {
      final quota = await client.getAccountQuota();

      expect(quota, isA<AccountQuota>());
      expect(quota.quotaSnapshots.containsKey('copilot'), isTrue);

      final copilotQuota = quota.quotaSnapshots['copilot']!;
      expect(copilotQuota.entitlementRequests, 1000);
      expect(copilotQuota.usedRequests, 250);
      expect(copilotQuota.remainingPercentage, 75.0);
      expect(copilotQuota.overageAllowedWithExhaustedQuota, isFalse);
    });
  });

  // ── State Guards ──────────────────────────────────────────────────────

  group('State Guards', () {
    test('RPC methods throw when not connected', () async {
      expect(() => client.ping(), throwsStateError);
      expect(() => client.getStatus(), throwsStateError);
      expect(() => client.getAuthStatus(), throwsStateError);
      expect(() => client.listModels(), throwsStateError);
      expect(() => client.listTools(), throwsStateError);
      expect(() => client.getAccountQuota(), throwsStateError);
      expect(() => client.listSessions(), throwsStateError);
      expect(
        () => client.deleteSession('any'),
        throwsStateError,
      );
    });

    test('createSession throws when not connected and autoStart is false',
        () async {
      final noAutoClient = CopilotClient(
        options: const CopilotClientOptions(autoStart: false),
        transport: server.clientTransport,
      );
      expect(
        () => noAutoClient.createSession(
          config: SessionConfig(onPermissionRequest: approveAllPermissions),
        ),
        throwsStateError,
      );
    });

    test('resumeSession throws when not connected and autoStart is false',
        () async {
      final noAutoClient = CopilotClient(
        options: const CopilotClientOptions(autoStart: false),
        transport: server.clientTransport,
      );
      expect(
        () => noAutoClient.resumeSession(
          config: ResumeSessionConfig(
            sessionId: 'any',
            onPermissionRequest: approveAllPermissions,
          ),
        ),
        throwsStateError,
      );
    });
  });

  // ── Handler Dispatch ──────────────────────────────────────────────────

  group('Handler Dispatch', () {
    setUp(() async {
      await client.start();
    });

    test('dispatches session events to the correct session', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final events = <SessionEvent>[];
      session.on((e) => events.add(e));

      await server.sendSessionEvent({
        'sessionId': session.sessionId,
        'type': 'assistant.message',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'messageId': 'msg-evt-1',
        'content': 'Hello!',
      });

      // Allow async delivery
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events[0], isA<AssistantMessageEvent>());
      expect((events[0] as AssistantMessageEvent).content, 'Hello!');
    });

    test('dispatches wrapped session.event payloads', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final events = <SessionEvent>[];
      session.on(events.add);

      await server.sendSessionEvent({
        'sessionId': session.sessionId,
        'event': {
          'type': 'assistant.message',
          'id': 'evt-wrapped-1',
          'timestamp': '2025-01-01T00:00:00Z',
          'messageId': 'msg-wrapped-1',
          'content': 'Wrapped hello!',
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events[0], isA<AssistantMessageEvent>());
      expect((events[0] as AssistantMessageEvent).content, 'Wrapped hello!');
    });

    test('routes wrapped events using nested event.sessionId fallback',
        () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final events = <SessionEvent>[];
      session.on(events.add);

      await server.sendSessionEvent({
        'event': {
          'sessionId': session.sessionId,
          'type': 'assistant.message',
          'id': 'evt-wrapped-2',
          'timestamp': '2025-01-01T00:00:00Z',
          'messageId': 'msg-1',
          'content': 'Nested sessionId hello!',
        },
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events[0], isA<AssistantMessageEvent>());
      expect((events[0] as AssistantMessageEvent).content,
          'Nested sessionId hello!');
    });

    test('reports error when session.event is missing sessionId', () async {
      final errors = <Object>[];
      client.onError = errors.add;

      await server.sendSessionEvent({
        'type': 'assistant.message',
        'id': 'evt-missing-session-id',
        'timestamp': '2025-01-01T00:00:00Z',
        'messageId': 'msg-1',
        'content': 'No session id',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('does not dispatch events to wrong session', () async {
      final s1 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final events1 = <SessionEvent>[];
      s1.on((e) => events1.add(e));

      // Send event for session 2
      await server.sendSessionEvent({
        'sessionId': 'fake-session-2',
        'type': 'assistant.message',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'messageId': 'msg-fake-2',
        'content': 'Hello!',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events1, isEmpty);
    });

    test('dispatches tool call to session and returns result', () async {
      final session = await client.createSession(
        config: SessionConfig(
          tools: [
            Tool(
              name: 'greet',
              description: 'Say hello',
              handler: (args, inv) async {
                final name = (args as Map<String, dynamic>)['name'] as String;
                return ToolResult.success('Hello, $name!');
              },
            ),
          ],
          onPermissionRequest: approveAllPermissions,
        ),
      );

      final response = await server.sendToolCallRequest(
        sessionId: session.sessionId,
        toolName: 'greet',
        toolCallId: 'tc-1',
        arguments: {'name': 'World'},
      );

      final result = response['result'] as Map<String, dynamic>;
      expect(result['resultType'], 'success');
      expect(result['textResultForLlm'], 'Hello, World!');
    });

    test('returns failure for unknown tool', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final response = await server.sendToolCallRequest(
        sessionId: session.sessionId,
        toolName: 'nonexistent',
        toolCallId: 'tc-1',
      );

      final result = response['result'] as Map<String, dynamic>;
      expect(result['resultType'], 'failure');
      expect(result['error'], contains('Unknown tool'));
    });

    test('dispatches permission request and returns result', () async {
      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: (req, inv) async {
            return PermissionResult.approved;
          },
        ),
      );

      final response = await server.sendPermissionRequest(
        sessionId: session.sessionId,
      );

      final result = response['result'] as Map<String, dynamic>;
      expect(result['kind'], 'approved');
    });

    test('dispatches user input request and returns response', () async {
      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
          onUserInputRequest: (req, inv) async {
            return UserInputResponse(answer: 'yes');
          },
        ),
      );

      final result = await server.sendUserInputRequest(
        sessionId: session.sessionId,
        question: 'Continue?',
        choices: ['yes', 'no'],
      );

      expect(result['answer'], 'yes');
    });

    test('user input request fails when no handler registered', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      // The server sends a userInput request, should get an error back
      expect(
        () => server.sendUserInputRequest(
          sessionId: session.sessionId,
          question: 'Continue?',
        ),
        throwsA(anything),
      );
    });

    test('dispatches hook invoke for preToolUse', () async {
      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
          hooks: SessionHooks(
            onPreToolUse: (input, inv) async {
              return PreToolUseOutput(
                permissionDecision: 'allow',
                permissionDecisionReason: 'Approved: ${input.toolName}',
              );
            },
          ),
        ),
      );

      final result = await server.sendHookInvoke(
        sessionId: session.sessionId,
        hookType: 'preToolUse',
        input: {'toolName': 'bash', 'toolCallId': 'tc-1'},
      );

      expect(result['permissionDecision'], 'allow');
      expect(result['permissionDecisionReason'], 'Approved: bash');
    });

    test('hook invoke returns empty map when no hooks configured', () async {
      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final result = await server.sendHookInvoke(
        sessionId: session.sessionId,
        hookType: 'preToolUse',
        input: {'toolName': 'bash'},
      );

      expect(result, isEmpty);
    });

    test('tool call with unknown session returns error', () async {
      expect(
        () => server.sendToolCallRequest(
          sessionId: 'nonexistent',
          toolName: 'test',
          toolCallId: 'tc-1',
        ),
        throwsA(anything),
      );
    });

    test('permission request with unknown session returns error', () async {
      expect(
        () => server.sendPermissionRequest(sessionId: 'nonexistent'),
        throwsA(anything),
      );
    });

    test('tool handler error is caught and returned as failure', () async {
      final session = await client.createSession(
        config: SessionConfig(
          tools: [
            Tool(
              name: 'broken',
              handler: (args, inv) async {
                throw Exception('Something went wrong');
              },
            ),
          ],
          onPermissionRequest: approveAllPermissions,
        ),
      );

      final response = await server.sendToolCallRequest(
        sessionId: session.sessionId,
        toolName: 'broken',
        toolCallId: 'tc-1',
      );

      final result = response['result'] as Map<String, dynamic>;
      expect(result['resultType'], 'failure');
      expect(result['error'], contains('Something went wrong'));
    });
  });

  // ── Multiple Sessions ─────────────────────────────────────────────────

  group('Multiple Sessions', () {
    test('can manage multiple concurrent sessions', () async {
      await client.start();

      final s1 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final s2 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final s3 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(client.sessions.length, 3);

      await s2.destroy();

      expect(client.sessions.length, 2);
      expect(client.sessions.containsKey(s1.sessionId), isTrue);
      expect(client.sessions.containsKey(s2.sessionId), isFalse);
      expect(client.sessions.containsKey(s3.sessionId), isTrue);
    });

    test('events are routed to correct session', () async {
      await client.start();

      final s1 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final s2 = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      final events1 = <SessionEvent>[];
      final events2 = <SessionEvent>[];
      s1.on((e) => events1.add(e));
      s2.on((e) => events2.add(e));

      await server.sendSessionEvent({
        'sessionId': s1.sessionId,
        'type': 'session.idle',
        'id': 'e1',
        'timestamp': '2025-01-01T00:00:00Z',
      });

      await server.sendSessionEvent({
        'sessionId': s2.sessionId,
        'type': 'assistant.message',
        'id': 'e2',
        'timestamp': '2025-01-01T00:00:00Z',
        'messageId': 'msg-e2',
        'content': 'Hello',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events1.length, 1);
      expect(events1[0], isA<SessionIdleEvent>());

      expect(events2.length, 1);
      expect(events2[0], isA<AssistantMessageEvent>());
    });
  });

  // ── Connection Close Handling ─────────────────────────────────────────

  group('Connection Close', () {
    test('sessions are notified and cleaned up on connection close', () async {
      await client.start();

      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(session.isDestroyed, isFalse);

      // Close the server-side transport to simulate connection drop
      await server.connection.close();

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(client.connectionState, ConnectionState.disconnected);
      expect(session.isDestroyed, isTrue);
    });
  });

  // ── New Feature Tests ──────────────────────────────────────────────────

  group('New client methods', () {
    setUp(() async {
      await client.start();
    });

    test('workspacePath is populated from createSession', () async {
      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
        ),
      );
      expect(session.workspacePath, '/tmp/workspace');
    });

    test('forceStop clears sessions without RPC', () async {
      await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
        ),
      );
      await client.forceStop();
      expect(client.connectionState, ConnectionState.disconnected);
    });

    test('getLastSessionId returns null initially', () async {
      final id = await client.getLastSessionId();
      expect(id, isNull);
    });

    test('getForegroundSessionId returns info', () async {
      final info = await client.getForegroundSessionId();
      expect(info, isA<ForegroundSessionInfo>());
    });

    test('setForegroundSessionId completes', () async {
      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
        ),
      );
      await client.setForegroundSessionId(session.sessionId);
    });

    test('lifecycle event subscription fires', () async {
      final events = <SessionLifecycleEvent>[];
      client.onLifecycleEvent((e) => events.add(e));

      await server.sendLifecycleEvent({
        'type': 'created',
        'sessionId': 'test-123',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
      expect(events.first.type, SessionLifecycleEventType.created);
      expect(events.first.sessionId, 'test-123');
    });

    test('typed lifecycle event subscription filters', () async {
      final created = <SessionLifecycleEvent>[];
      final deleted = <SessionLifecycleEvent>[];
      client.onLifecycleEvent(
        (e) => created.add(e),
        SessionLifecycleEventType.created,
      );
      client.onLifecycleEvent(
        (e) => deleted.add(e),
        SessionLifecycleEventType.deleted,
      );

      await server.sendLifecycleEvent({
        'type': 'created',
        'sessionId': 'test-1',
      });
      await server.sendLifecycleEvent({
        'type': 'deleted',
        'sessionId': 'test-2',
      });

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(created, hasLength(1));
      expect(deleted, hasLength(1));
      expect(created.first.sessionId, 'test-1');
      expect(deleted.first.sessionId, 'test-2');
    });

    test('lifecycle unsubscribe works', () async {
      final events = <SessionLifecycleEvent>[];
      final unsub = client.onLifecycleEvent((e) => events.add(e));

      await server.sendLifecycleEvent({
        'type': 'created',
        'sessionId': 'a',
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      unsub();

      await server.sendLifecycleEvent({
        'type': 'deleted',
        'sessionId': 'b',
      });
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(events, hasLength(1));
    });
  });

  group('ResumeSession full config forwarding', () {
    setUp(() async {
      await client.start();
    });

    test('resumeSession forwards all config fields', () async {
      // First create a session so we have a valid session ID
      final initial = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
        ),
      );

      Map<String, dynamic>? resumeParams;
      server.overrideHandler('session.resume', (params) async {
        resumeParams = Map<String, dynamic>.from(params as Map);
        return {
          'sessionId': initial.sessionId,
          'workspacePath': '/tmp/workspace',
        };
      });

      await client.resumeSession(
        config: ResumeSessionConfig(
          sessionId: initial.sessionId,
          model: 'gpt-4o',
          streaming: false,
          reasoningEffort: ReasoningEffort.high,
          onPermissionRequest: approveAllPermissions,
        ),
      );

      expect(resumeParams, isNotNull);
      expect(resumeParams!['sessionId'], initial.sessionId);
      expect(resumeParams!['model'], 'gpt-4o');
      expect(resumeParams!['streaming'], isFalse);
      expect(resumeParams!['reasoningEffort'], 'high');
      expect(resumeParams!['requestPermission'], isTrue);
      expect(resumeParams!['envValueMode'], 'direct');
    });
  });

  // ── Dynamic Handler Registration ───────────────────────────────────────

  group('Dynamic handler registration', () {
    setUp(() async {
      await client.start();
    });

    test('dynamic permission handler overrides config handler', () async {
      var configCalled = false;
      var dynamicCalled = false;

      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: (req, inv) async {
            configCalled = true;
            return PermissionResult.denied;
          },
        ),
      );

      session.registerPermissionHandler((req, inv) async {
        dynamicCalled = true;
        return PermissionResult.approved;
      });

      final response = await server.sendPermissionRequest(
        sessionId: session.sessionId,
      );

      final result = response['result'] as Map<String, dynamic>;
      expect(dynamicCalled, isTrue);
      expect(configCalled, isFalse);
      expect(result['kind'], 'approved');
    });

    test('dynamic hooks override config hooks', () async {
      var configHookCalled = false;
      var dynamicHookCalled = false;

      final session = await client.createSession(
        config: SessionConfig(
          onPermissionRequest: approveAllPermissions,
          hooks: SessionHooks(
            onPreToolUse: (input, inv) async {
              configHookCalled = true;
              return const PreToolUseOutput();
            },
          ),
        ),
      );

      session.registerHooks(SessionHooks(
        onPreToolUse: (input, inv) async {
          dynamicHookCalled = true;
          return PreToolUseOutput(permissionDecision: 'allow');
        },
      ));

      final result = await server.sendHookInvoke(
        sessionId: session.sessionId,
        hookType: 'preToolUse',
        input: {'toolName': 'test', 'timestamp': 0, 'cwd': ''},
      );

      expect(dynamicHookCalled, isTrue);
      expect(configHookCalled, isFalse);
      expect(result['permissionDecision'], 'allow');
    });
  });

  // ── AutoStart ──────────────────────────────────────────────────────────

  group('AutoStart', () {
    test('createSession auto-starts when autoStart is true', () async {
      expect(client.isConnected, isFalse);

      final session = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );

      expect(client.isConnected, isTrue);
      expect(session.sessionId, isNotEmpty);
    });

    test('resumeSession auto-starts when autoStart is true', () async {
      // Create a session first (starts implicitly via autoStart)
      final initial = await client.createSession(
        config: SessionConfig(onPermissionRequest: approveAllPermissions),
      );
      final sessionId = initial.sessionId;

      // Stop the client — transport closes
      await client.stop();
      await server.close();

      // Create fresh transport pair (simulates reconnect)
      server = FakeServer();
      // Pre-register the session so resume finds it
      server.sessions[sessionId] = FakeSession(sessionId: sessionId);
      client = CopilotClient(
        options: const CopilotClientOptions(),
        transport: server.clientTransport,
      );

      expect(client.isConnected, isFalse);

      // Resume should auto-start the new transport
      final resumed = await client.resumeSession(
        config: ResumeSessionConfig(
          sessionId: sessionId,
          onPermissionRequest: approveAllPermissions,
        ),
      );

      expect(client.isConnected, isTrue);
      expect(resumed.sessionId, sessionId);
    });
  });
}
