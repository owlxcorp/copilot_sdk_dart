import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:test/test.dart';

void main() {
  group('SessionEvent.fromJson', () {
    test('parses session.start event', () {
      final json = {
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'type': 'session.start',
        'sessionId': 'sess-abc',
        'version': 2,
        'producer': 'copilot-cli',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionStartEvent>());

      final start = event as SessionStartEvent;
      expect(start.id, 'evt-1');
      expect(start.sessionId, 'sess-abc');
      expect(start.version, 2);
      expect(start.producer, 'copilot-cli');
      expect(start.type, 'session.start');
    });

    test('parses assistant.message event', () {
      final json = {
        'id': 'evt-2',
        'timestamp': '2025-01-01T00:00:01Z',
        'type': 'assistant.message',
        'content': 'Hello, world!',
        'role': 'assistant',
        'parentId': 'turn-1',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<AssistantMessageEvent>());

      final msg = event as AssistantMessageEvent;
      expect(msg.content, 'Hello, world!');
      expect(msg.role, 'assistant');
      expect(msg.parentId, 'turn-1');
    });

    test('parses tool.execution_start event', () {
      final json = {
        'id': 'evt-3',
        'timestamp': '2025-01-01T00:00:02Z',
        'type': 'tool.execution_start',
        'toolName': 'read_file',
        'toolCallId': 'call-xyz',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<ToolExecutionStartEvent>());

      final tool = event as ToolExecutionStartEvent;
      expect(tool.toolName, 'read_file');
      expect(tool.toolCallId, 'call-xyz');
    });

    test('parses session.idle event', () {
      final json = {
        'id': 'evt-4',
        'timestamp': '2025-01-01T00:00:03Z',
        'type': 'session.idle',
        'reason': 'turn_complete',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionIdleEvent>());
      expect((event as SessionIdleEvent).reason, 'turn_complete');
    });

    test('parses session.error event', () {
      final json = {
        'id': 'evt-5',
        'timestamp': '2025-01-01T00:00:04Z',
        'type': 'session.error',
        'error': 'Rate limit exceeded',
        'code': 'rate_limit',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionErrorEvent>());

      final err = event as SessionErrorEvent;
      expect(err.error, 'Rate limit exceeded');
      expect(err.code, 'rate_limit');
    });

    test('parses tool.call event', () {
      final json = {
        'id': 'evt-6',
        'timestamp': '2025-01-01T00:00:05Z',
        'type': 'tool.call',
        'toolName': 'weather',
        'toolCallId': 'call-123',
        'arguments': {'city': 'Seattle'},
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<ToolCallEvent>());

      final call = event as ToolCallEvent;
      expect(call.toolName, 'weather');
      expect(call.arguments, {'city': 'Seattle'});
    });

    test('parses subagent.started event', () {
      final json = {
        'id': 'evt-7',
        'timestamp': '2025-01-01T00:00:06Z',
        'type': 'subagent.started',
        'agentId': 'agent-1',
        'agentName': 'CodeReviewer',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SubagentStartedEvent>());

      final sub = event as SubagentStartedEvent;
      expect(sub.agentId, 'agent-1');
      expect(sub.agentName, 'CodeReviewer');
    });

    test('unknown type returns UnknownEvent', () {
      final json = {
        'id': 'evt-8',
        'timestamp': '2025-01-01T00:00:07Z',
        'type': 'future.new_event_type',
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<UnknownEvent>());
      expect(event.type, 'future.new_event_type');
      expect((event as UnknownEvent).data, json);
    });

    test('ephemeral flag defaults to false', () {
      final json = {
        'id': 'evt-9',
        'timestamp': '2025-01-01T00:00:08Z',
        'type': 'session.idle',
      };

      final event = SessionEvent.fromJson(json);
      expect(event.ephemeral, false);
    });

    test('ephemeral flag parsed when true', () {
      final json = {
        'id': 'evt-10',
        'timestamp': '2025-01-01T00:00:09Z',
        'type': 'assistant.thinking',
        'content': 'Let me think...',
        'ephemeral': true,
      };

      final event = SessionEvent.fromJson(json);
      expect(event.ephemeral, true);
    });

    test('exhaustive pattern matching works', () {
      final events = <SessionEvent>[
        SessionEvent.fromJson({
          'id': '1',
          'timestamp': '2025-01-01T00:00:00Z',
          'type': 'session.start',
          'sessionId': 's1',
        }),
        SessionEvent.fromJson({
          'id': '2',
          'timestamp': '2025-01-01T00:00:01Z',
          'type': 'assistant.message',
          'content': 'Hi',
        }),
        SessionEvent.fromJson({
          'id': '3',
          'timestamp': '2025-01-01T00:00:02Z',
          'type': 'session.idle',
        }),
      ];

      final types = <String>[];
      for (final event in events) {
        // Dart 3 exhaustive switch compiles
        switch (event) {
          case SessionStartEvent():
            types.add('start');
          case AssistantMessageEvent(:final content):
            types.add('msg:$content');
          case SessionIdleEvent():
            types.add('idle');
          case _:
            types.add('other');
        }
      }

      expect(types, ['start', 'msg:Hi', 'idle']);
    });
  });
}
