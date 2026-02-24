import 'dart:async';

import 'package:copilot_sdk_dart/src/session.dart';
import 'package:copilot_sdk_dart/src/transport/json_rpc_connection.dart';
import 'package:copilot_sdk_dart/src/types/session_config.dart';
import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:copilot_sdk_dart/src/types/tool_types.dart';
import 'package:test/test.dart';

import 'transport/mock_transport.dart';

/// Creates a test session with a mock transport pair.
_TestSession createTestSession({
  String sessionId = 'test-session-1',
  SessionConfig? config,
  List<Tool>? tools,
}) {
  final pair = MockTransportPair();
  final serverConn = JsonRpcConnection(pair.server);
  final clientConn = JsonRpcConnection(pair.client);

  // Register default server handlers
  serverConn.registerRequestHandler('session.send', (p) async {
    return {'messageId': 'msg-1'};
  });
  serverConn.registerRequestHandler('session.getMessages', (p) async {
    return {'events': <Map<String, dynamic>>[]};
  });
  serverConn.registerRequestHandler('session.abort', (p) async {
    return <String, dynamic>{};
  });
  serverConn.registerRequestHandler('session.destroy', (p) async {
    return <String, dynamic>{};
  });
  serverConn.registerRequestHandler(
    'session.model.getCurrent',
    (p) async => {'modelId': 'gpt-4'},
  );
  serverConn.registerRequestHandler(
    'session.model.switchTo',
    (p) async => <String, dynamic>{},
  );
  serverConn.registerRequestHandler(
    'session.mode.get',
    (p) async => {'mode': 'interactive'},
  );
  serverConn.registerRequestHandler(
    'session.mode.set',
    (p) async => <String, dynamic>{},
  );
  serverConn.registerRequestHandler(
    'session.plan.read',
    (p) async => {'plan': '# Plan'},
  );
  serverConn.registerRequestHandler(
    'session.plan.update',
    (p) async => <String, dynamic>{},
  );
  serverConn.registerRequestHandler(
    'session.plan.delete',
    (p) async => <String, dynamic>{},
  );
  serverConn.registerRequestHandler(
    'session.workspace.listFiles',
    (p) async => {
      'files': ['a.dart', 'b.dart'],
    },
  );
  serverConn.registerRequestHandler(
    'session.workspace.readFile',
    (p) async => {'content': 'file content'},
  );
  serverConn.registerRequestHandler(
    'session.workspace.createFile',
    (p) async => <String, dynamic>{},
  );
  serverConn.registerRequestHandler(
    'session.fleet.start',
    (p) async => <String, dynamic>{},
  );

  final effectiveConfig = config ??
      SessionConfig(
        tools: tools ?? [],
        onPermissionRequest: approveAllPermissions,
      );

  final session = CopilotSession(
    sessionId: sessionId,
    connection: clientConn,
    config: effectiveConfig,
  );

  return _TestSession(
    session: session,
    pair: pair,
    serverConn: serverConn,
    clientConn: clientConn,
  );
}

class _TestSession {
  _TestSession({
    required this.session,
    required this.pair,
    required this.serverConn,
    required this.clientConn,
  });

  final CopilotSession session;
  final MockTransportPair pair;
  final JsonRpcConnection serverConn;
  final JsonRpcConnection clientConn;

  Future<void> close() async {
    await serverConn.close();
    await clientConn.close();
    await pair.close();
  }
}

SessionEvent _makeEvent(String type, {Map<String, dynamic> extra = const {}}) {
  return SessionEvent.fromJson({
    'type': type,
    'id': 'evt-${DateTime.now().microsecondsSinceEpoch}',
    'timestamp': '2025-01-01T00:00:00Z',
    ...extra,
  });
}

void main() {
  // ── Event Handlers ────────────────────────────────────────────────────

  group('Event Handlers', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('on() handler receives all events', () {
      final events = <SessionEvent>[];
      ts.session.on((e) => events.add(e));

      ts.session.handleEvent(
        _makeEvent('session.idle'),
      );
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'hi'}),
      );

      expect(events, hasLength(2));
    });

    test('on() returns working unsubscribe function', () {
      final events = <SessionEvent>[];
      final unsub = ts.session.on((e) => events.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));
      expect(events, hasLength(1));

      unsub();
      ts.session.handleEvent(_makeEvent('session.idle'));
      expect(events, hasLength(1)); // no new events
    });

    test('multiple handlers all receive events', () {
      final events1 = <SessionEvent>[];
      final events2 = <SessionEvent>[];
      final events3 = <SessionEvent>[];

      ts.session.on((e) => events1.add(e));
      ts.session.on((e) => events2.add(e));
      ts.session.on((e) => events3.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(events1, hasLength(1));
      expect(events2, hasLength(1));
      expect(events3, hasLength(1));
    });

    test('unsubscribing one handler does not affect others', () {
      final events1 = <SessionEvent>[];
      final events2 = <SessionEvent>[];

      final unsub1 = ts.session.on((e) => events1.add(e));
      ts.session.on((e) => events2.add(e));

      unsub1();

      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(events1, isEmpty);
      expect(events2, hasLength(1));
    });

    test('double unsubscribe is safe', () {
      final unsub = ts.session.on((e) {});

      unsub();
      unsub(); // should not throw
    });

    test('handlers are called in registration order', () {
      final order = <int>[];

      ts.session.on((_) => order.add(1));
      ts.session.on((_) => order.add(2));
      ts.session.on((_) => order.add(3));

      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(order, [1, 2, 3]);
    });
  });

  // ── onType ────────────────────────────────────────────────────────────

  group('onType', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('only receives events of the specified type', () {
      final messages = <AssistantMessageEvent>[];
      ts.session.onType<AssistantMessageEvent>((e) => messages.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'hi'}),
      );
      ts.session
          .handleEvent(_makeEvent('session.error', extra: {'error': 'x'}));
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'there'}),
      );

      expect(messages, hasLength(2));
      expect(messages[0].content, 'hi');
      expect(messages[1].content, 'there');
    });

    test('onType unsubscribe works', () {
      final messages = <AssistantMessageEvent>[];
      final unsub =
          ts.session.onType<AssistantMessageEvent>((e) => messages.add(e));

      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'first'}),
      );
      unsub();
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'second'}),
      );

      expect(messages, hasLength(1));
    });
  });

  // ── once ──────────────────────────────────────────────────────────────

  group('once', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('fires only once and auto-removes', () {
      final events = <SessionEvent>[];
      ts.session.once((e) => events.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(events, hasLength(1));
    });

    test('once unsubscribe prevents any call', () {
      final events = <SessionEvent>[];
      final unsub = ts.session.once((e) => events.add(e));

      unsub();
      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(events, isEmpty);
    });

    test('multiple once handlers each fire once', () {
      final calls1 = <SessionEvent>[];
      final calls2 = <SessionEvent>[];

      ts.session.once((e) => calls1.add(e));
      ts.session.once((e) => calls2.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(_makeEvent('session.idle'));

      expect(calls1, hasLength(1));
      expect(calls2, hasLength(1));
    });
  });

  // ── Event Stream ──────────────────────────────────────────────────────

  group('Event Stream', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('events property returns a broadcast stream', () {
      final stream = ts.session.events;

      expect(stream, isA<Stream<SessionEvent>>());
      expect(stream.isBroadcast, isTrue);
    });

    test('events stream receives dispatched events', () async {
      final received = <SessionEvent>[];
      final sub = ts.session.events.listen((e) => received.add(e));

      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'hi'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(2));

      await sub.cancel();
    });

    test('events stream supports where/map', () async {
      final messages = <String>[];
      final sub = ts.session.events
          .where((e) => e is AssistantMessageEvent)
          .cast<AssistantMessageEvent>()
          .map((e) => e.content)
          .listen((c) => messages.add(c));

      ts.session.handleEvent(_makeEvent('session.idle'));
      ts.session.handleEvent(
        _makeEvent('assistant.message', extra: {'content': 'hello'}),
      );

      await Future<void>.delayed(Duration.zero);

      expect(messages, ['hello']);

      await sub.cancel();
    });
  });

  // ── Tool Management ───────────────────────────────────────────────────

  group('Tool Management', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('addTool registers tool for handling', () async {
      ts.session.addTool(Tool(
        name: 'test_tool',
        handler: (args, inv) async => ToolResult.success('ok'),
      ));

      final result = await ts.session.handleToolCall(
        'test_tool',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'test_tool',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result, isA<ToolResultSuccess>());
      expect((result as ToolResultSuccess).text, 'ok');
    });

    test('removeTool prevents future handling', () async {
      ts.session.addTool(Tool(
        name: 'temp',
        handler: (args, inv) async => ToolResult.success('ok'),
      ));

      ts.session.removeTool('temp');

      final result = await ts.session.handleToolCall(
        'temp',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'temp',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result, isA<ToolResultFailure>());
    });

    test('session-local tools override config tools', () async {
      final configTool = Tool(
        name: 'shared',
        handler: (args, inv) async => ToolResult.success('from config'),
      );

      ts = createTestSession(tools: [configTool]);

      // Add a local override
      ts.session.addTool(Tool(
        name: 'shared',
        handler: (args, inv) async => ToolResult.success('from local'),
      ));

      final result = await ts.session.handleToolCall(
        'shared',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'shared',
          arguments: <String, dynamic>{},
        ),
      );

      expect((result as ToolResultSuccess).text, 'from local');
    });

    test('config tools are checked when no local tool', () async {
      final configTool = Tool(
        name: 'config_only',
        handler: (args, inv) async => ToolResult.success('config result'),
      );

      ts = createTestSession(tools: [configTool]);

      final result = await ts.session.handleToolCall(
        'config_only',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'config_only',
          arguments: <String, dynamic>{},
        ),
      );

      expect((result as ToolResultSuccess).text, 'config result');
    });

    test('unknown tool returns failure', () async {
      final result = await ts.session.handleToolCall(
        'nonexistent',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'nonexistent',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result, isA<ToolResultFailure>());
      expect((result as ToolResultFailure).error, contains('Unknown tool'));
    });

    test('tool handler exception returns failure', () async {
      ts.session.addTool(Tool(
        name: 'crasher',
        handler: (args, inv) async {
          throw FormatException('bad data');
        },
      ));

      final result = await ts.session.handleToolCall(
        'crasher',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-1',
          toolName: 'crasher',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result, isA<ToolResultFailure>());
      expect((result as ToolResultFailure).error, contains('bad data'));
    });

    test('tool handler receives correct arguments', () async {
      dynamic receivedArgs;
      ToolInvocation? receivedInv;

      ts.session.addTool(Tool(
        name: 'echo',
        handler: (args, inv) async {
          receivedArgs = args;
          receivedInv = inv;
          return ToolResult.success('done');
        },
      ));

      final testArgs = {'key': 'value', 'count': 42};
      await ts.session.handleToolCall(
        'echo',
        testArgs,
        const ToolInvocation(
          sessionId: 'test-session-1',
          toolCallId: 'tc-99',
          toolName: 'echo',
          arguments: {'key': 'value', 'count': 42},
        ),
      );

      expect(receivedArgs, testArgs);
      expect(receivedInv!.toolCallId, 'tc-99');
      expect(receivedInv!.sessionId, 'test-session-1');
    });
  });

  // ── Messaging ─────────────────────────────────────────────────────────

  group('Messaging', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('send returns message ID', () async {
      final msgId = await ts.session.send('Hello');

      expect(msgId, 'msg-1');
    });

    test('send includes attachments in params', () async {
      await ts.session.send(
        'Check this',
        attachments: [Attachment.file('/tmp/test.txt')],
      );

      // Verify the sent message contains attachments
      final sent = ts.pair.client.sentMessages.last;
      final params = sent['params'] as Map<String, dynamic>;
      expect(params['attachments'], isNotNull);
    });

    test('send includes mode in params', () async {
      await ts.session.send(
        'Run in autopilot',
        mode: AgentMode.autopilot,
      );

      final sent = ts.pair.client.sentMessages.last;
      final params = sent['params'] as Map<String, dynamic>;
      expect(params['mode'], 'autopilot');
    });

    test('sendAndWait collects assistant messages and returns on idle',
        () async {
      // Override server to simulate response flow
      ts.serverConn.removeRequestHandler('session.send');
      ts.serverConn.registerRequestHandler('session.send', (p) async {
        // Simulate the server sending events after a brief delay
        Future.delayed(const Duration(milliseconds: 10), () {
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'assistant.message',
            'id': 'e1',
            'timestamp': '2025-01-01T00:00:00Z',
            'content': 'Hello ',
          }));
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'assistant.message',
            'id': 'e2',
            'timestamp': '2025-01-01T00:00:01Z',
            'content': 'World!',
          }));
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'session.idle',
            'id': 'e3',
            'timestamp': '2025-01-01T00:00:02Z',
          }));
        });
        return {'messageId': 'msg-wait-1'};
      });

      final reply = await ts.session.sendAndWait('Hi');

      expect(reply, isNotNull);
      expect(reply!.content, 'Hello World!');
      expect(reply.messageId, 'msg-wait-1');
    });

    test('sendAndWait returns null on timeout', () async {
      // Override server to never send idle
      ts.serverConn.removeRequestHandler('session.send');
      ts.serverConn.registerRequestHandler('session.send', (p) async {
        return {'messageId': 'msg-timeout'};
      });

      final reply = await ts.session.sendAndWait(
        'Hi',
        timeout: const Duration(milliseconds: 100),
      );

      expect(reply, isNull);
    });

    test('sendAndWait propagates session error', () async {
      ts.serverConn.removeRequestHandler('session.send');
      ts.serverConn.registerRequestHandler('session.send', (p) async {
        Future.delayed(const Duration(milliseconds: 10), () {
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'session.error',
            'id': 'e1',
            'timestamp': '2025-01-01T00:00:00Z',
            'error': 'rate limit exceeded',
          }));
        });
        return {'messageId': 'msg-err'};
      });

      expect(
        () => ts.session.sendAndWait('Hi'),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('rate limit exceeded'),
        )),
      );
    });

    test('sendAndWait handles idle event before send response resolves',
        () async {
      ts.serverConn.removeRequestHandler('session.send');
      ts.serverConn.registerRequestHandler('session.send', (p) async {
        ts.session.handleEvent(SessionEvent.fromJson({
          'type': 'assistant.message',
          'id': 'e1',
          'timestamp': '2025-01-01T00:00:00Z',
          'content': 'Fast reply',
        }));
        ts.session.handleEvent(SessionEvent.fromJson({
          'type': 'session.idle',
          'id': 'e2',
          'timestamp': '2025-01-01T00:00:01Z',
        }));
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return {'messageId': 'msg-early-idle'};
      });

      final reply = await ts.session.sendAndWait('Hi');
      expect(reply, isNotNull);
      expect(reply!.content, 'Fast reply');
      expect(reply.messageId, 'msg-early-idle');
    });

    test('sendAndWait collects assistant.message_delta events', () async {
      ts.serverConn.removeRequestHandler('session.send');
      ts.serverConn.registerRequestHandler('session.send', (p) async {
        Future.delayed(const Duration(milliseconds: 10), () {
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'assistant.message_delta',
            'id': 'e1',
            'timestamp': '2025-01-01T00:00:00Z',
            'data': {
              'messageId': 'assistant-msg-1',
              'deltaContent': 'Hello ',
            },
          }));
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'assistant.message_delta',
            'id': 'e2',
            'timestamp': '2025-01-01T00:00:01Z',
            'data': {
              'messageId': 'assistant-msg-1',
              'deltaContent': 'World!',
            },
          }));
          ts.session.handleEvent(SessionEvent.fromJson({
            'type': 'session.idle',
            'id': 'e3',
            'timestamp': '2025-01-01T00:00:02Z',
          }));
        });
        return {'messageId': 'msg-delta'};
      });

      final reply = await ts.session.sendAndWait('Hi');

      expect(reply, isNotNull);
      expect(reply!.content, 'Hello World!');
      expect(reply.messageId, 'msg-delta');
    });
  });

  // ── Session RPC Methods ───────────────────────────────────────────────

  group('Session RPC Methods', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('getMessages returns event list', () async {
      final messages = await ts.session.getMessages();

      expect(messages, isA<List<SessionEvent>>());
    });

    test('abort completes without error', () async {
      await ts.session.abort();
    });

    test('getCurrentModel returns model ID', () async {
      final model = await ts.session.getCurrentModel();

      expect(model, 'gpt-4');
    });

    test('switchModel completes without error', () async {
      await ts.session.switchModel('claude-sonnet');
    });

    test('getMode returns agent mode', () async {
      final mode = await ts.session.getMode();

      expect(mode, AgentMode.interactive);
    });

    test('setMode completes without error', () async {
      await ts.session.setMode(AgentMode.autopilot);
    });

    test('readPlan returns plan content', () async {
      final plan = await ts.session.readPlan();

      expect(plan, '# Plan');
    });

    test('updatePlan completes without error', () async {
      await ts.session.updatePlan('# New Plan');
    });

    test('deletePlan completes without error', () async {
      await ts.session.deletePlan();
    });

    test('listWorkspaceFiles returns file list', () async {
      final files = await ts.session.listWorkspaceFiles();

      expect(files, ['a.dart', 'b.dart']);
    });

    test('readWorkspaceFile returns file content', () async {
      final content = await ts.session.readWorkspaceFile('a.dart');

      expect(content, 'file content');
    });

    test('createWorkspaceFile completes without error', () async {
      await ts.session.createWorkspaceFile('new.dart', 'void main() {}');
    });

    test('startFleet completes without error', () async {
      await ts.session.startFleet();
    });

    test('startFleet with prompt completes without error', () async {
      await ts.session.startFleet(prompt: 'Build the app');
    });
  });

  // ── Destroyed Session ─────────────────────────────────────────────────

  group('Destroyed Session', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('destroy sets isDestroyed to true', () async {
      expect(ts.session.isDestroyed, isFalse);

      await ts.session.destroy();

      expect(ts.session.isDestroyed, isTrue);
    });

    test('destroy is idempotent', () async {
      await ts.session.destroy();
      await ts.session.destroy(); // should not throw
    });

    test('destroy sends only one RPC when called concurrently', () async {
      var destroyCalls = 0;
      ts.serverConn.removeRequestHandler('session.destroy');
      ts.serverConn.registerRequestHandler('session.destroy', (p) async {
        destroyCalls += 1;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return <String, dynamic>{};
      });

      await Future.wait([ts.session.destroy(), ts.session.destroy()]);
      expect(destroyCalls, 1);
    });

    test('destroy Completer is set before _destroyImpl executes', () async {
      // Calling destroy() three times synchronously must still result in
      // exactly one RPC call — the Completer guard must be visible to all
      // subsequent callers before any async work begins.
      var destroyCalls = 0;
      ts.serverConn.removeRequestHandler('session.destroy');
      ts.serverConn.registerRequestHandler('session.destroy', (p) async {
        destroyCalls += 1;
        return <String, dynamic>{};
      });

      final f1 = ts.session.destroy();
      final f2 = ts.session.destroy();
      final f3 = ts.session.destroy();
      await Future.wait([f1, f2, f3]);
      expect(destroyCalls, 1);
    });

    test('destroy clears event handlers', () async {
      final events = <SessionEvent>[];
      ts.session.on((e) => events.add(e));

      await ts.session.destroy();

      // Events should not be dispatched after destroy
      ts.session.handleEvent(_makeEvent('session.idle'));
      expect(events, isEmpty);
    });

    test('destroy clears tools', () async {
      ts.session.addTool(Tool(
        name: 'test',
        handler: (a, i) async => ToolResult.success('ok'),
      ));

      await ts.session.destroy();

      final result = await ts.session.handleToolCall(
        'test',
        <String, dynamic>{},
        const ToolInvocation(
          sessionId: 's1',
          toolCallId: 'tc-1',
          toolName: 'test',
          arguments: <String, dynamic>{},
        ),
      );

      expect(result, isA<ToolResultFailure>());
    });

    test('destroy closes event stream', () async {
      final stream = ts.session.events;
      final events = <SessionEvent>[];
      final sub = stream.listen(
        (e) => events.add(e),
      );

      await ts.session.destroy();
      await Future<void>.delayed(Duration.zero);

      // Stream should be closed
      await sub.cancel();
    });

    test('destroy calls onDestroyed callback', () async {
      var called = false;
      ts.session.onDestroyed = () => called = true;

      await ts.session.destroy();

      expect(called, isTrue);
    });

    test('send throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.send('hi'), throwsStateError);
    });

    test('sendAndWait throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.sendAndWait('hi'), throwsStateError);
    });

    test('getMessages throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.getMessages(), throwsStateError);
    });

    test('abort throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.abort(), throwsStateError);
    });

    test('getCurrentModel throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.getCurrentModel(), throwsStateError);
    });

    test('switchModel throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.switchModel('x'), throwsStateError);
    });

    test('getMode throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.getMode(), throwsStateError);
    });

    test('setMode throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.setMode(AgentMode.plan), throwsStateError);
    });

    test('readPlan throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.readPlan(), throwsStateError);
    });

    test('listWorkspaceFiles throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.listWorkspaceFiles(), throwsStateError);
    });

    test('startFleet throws after destroy', () async {
      await ts.session.destroy();

      expect(() => ts.session.startFleet(), throwsStateError);
    });
  });

  // ── handleConnectionClose ─────────────────────────────────────────────

  group('handleConnectionClose', () {
    late _TestSession ts;

    setUp(() {
      ts = createTestSession();
    });

    tearDown(() async {
      await ts.close();
    });

    test('marks session as destroyed', () {
      ts.session.handleConnectionClose();

      expect(ts.session.isDestroyed, isTrue);
    });

    test('closes event stream', () async {
      final stream = ts.session.events;
      final completer = Completer<void>();
      final sub = stream.listen(null, onDone: () => completer.complete());

      ts.session.handleConnectionClose();

      await completer.future.timeout(const Duration(seconds: 1));
      await sub.cancel();
    });
  });

  // ── AssistantReply ────────────────────────────────────────────────────

  group('AssistantReply', () {
    test('toString returns content', () {
      const reply = AssistantReply(content: 'Hello World');

      expect(reply.toString(), 'Hello World');
    });

    test('messageId is accessible', () {
      const reply = AssistantReply(content: 'test', messageId: 'msg-42');

      expect(reply.messageId, 'msg-42');
    });

    test('messageId can be null', () {
      const reply = AssistantReply(content: 'test');

      expect(reply.messageId, isNull);
    });
  });
}
