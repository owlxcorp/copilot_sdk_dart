import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:test/test.dart';

void main() {
  group('SessionEvent.fromJson', () {
    test('parses session.start event with data sub-object', () {
      final json = {
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'type': 'session.start',
        'data': {
          'sessionId': 'sess-abc',
          'version': 2,
          'producer': 'copilot-cli',
          'copilotVersion': '1.0.0',
          'startTime': '2025-01-01T00:00:00Z',
        },
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionStartEvent>());

      final start = event as SessionStartEvent;
      expect(start.id, 'evt-1');
      expect(start.sessionId, 'sess-abc');
      expect(start.version, 2);
      expect(start.producer, 'copilot-cli');
      expect(start.copilotVersion, '1.0.0');
      expect(start.type, 'session.start');
    });

    test('parses session.start with flat format (backward compat)', () {
      final json = {
        'id': 'evt-1b',
        'timestamp': '2025-01-01T00:00:00Z',
        'type': 'session.start',
        'sessionId': 'sess-flat',
        'version': 3,
        'producer': 'copilot-vscode',
        'copilotVersion': '2.0.0',
        'startTime': '2025-01-01T00:00:00Z',
      };

      final event = SessionEvent.fromJson(json) as SessionStartEvent;
      expect(event.sessionId, 'sess-flat');
      expect(event.version, 3);
      expect(event.producer, 'copilot-vscode');
    });

    test('parses assistant.message event', () {
      final json = {
        'id': 'evt-2',
        'timestamp': '2025-01-01T00:00:01Z',
        'type': 'assistant.message',
        'parentId': 'turn-1',
        'data': {
          'messageId': 'msg-1',
          'content': 'Hello, world!',
        },
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<AssistantMessageEvent>());

      final msg = event as AssistantMessageEvent;
      expect(msg.content, 'Hello, world!');
      expect(msg.messageId, 'msg-1');
      expect(msg.parentId, 'turn-1');
    });

    test('parses tool.execution_start event', () {
      final json = {
        'id': 'evt-3',
        'timestamp': '2025-01-01T00:00:02Z',
        'type': 'tool.execution_start',
        'data': {
          'toolName': 'read_file',
          'toolCallId': 'call-xyz',
        },
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
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionIdleEvent>());
    });

    test('parses session.error event', () {
      final json = {
        'id': 'evt-5',
        'timestamp': '2025-01-01T00:00:04Z',
        'type': 'session.error',
        'data': {
          'errorType': 'rate_limit',
          'message': 'Rate limit exceeded',
          'statusCode': 429,
        },
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SessionErrorEvent>());

      final err = event as SessionErrorEvent;
      expect(err.errorType, 'rate_limit');
      expect(err.message, 'Rate limit exceeded');
      expect(err.statusCode, 429);
    });

    test('parses assistant.reasoning event', () {
      final json = {
        'id': 'evt-6',
        'timestamp': '2025-01-01T00:00:05Z',
        'type': 'assistant.reasoning',
        'data': {
          'reasoningId': 'r-1',
          'content': 'Let me think...',
        },
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<AssistantReasoningEvent>());

      final r = event as AssistantReasoningEvent;
      expect(r.reasoningId, 'r-1');
      expect(r.content, 'Let me think...');
    });

    test('parses subagent.started event', () {
      final json = {
        'id': 'evt-7',
        'timestamp': '2025-01-01T00:00:06Z',
        'type': 'subagent.started',
        'data': {
          'toolCallId': 'tc-1',
          'agentName': 'CodeReviewer',
          'agentDisplayName': 'Code Reviewer',
          'agentDescription': 'Reviews code',
        },
      };

      final event = SessionEvent.fromJson(json);
      expect(event, isA<SubagentStartedEvent>());

      final sub = event as SubagentStartedEvent;
      expect(sub.toolCallId, 'tc-1');
      expect(sub.agentName, 'CodeReviewer');
      expect(sub.agentDisplayName, 'Code Reviewer');
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

    test('session.idle defaults ephemeral to true', () {
      final json = {
        'id': 'evt-9',
        'timestamp': '2025-01-01T00:00:08Z',
        'type': 'session.idle',
      };

      final event = SessionEvent.fromJson(json);
      expect(event.ephemeral, true);
    });

    test('ephemeral flag parsed when explicitly set', () {
      final json = {
        'id': 'evt-10',
        'timestamp': '2025-01-01T00:00:09Z',
        'type': 'assistant.reasoning',
        'data': {
          'reasoningId': 'r-1',
          'content': 'Let me think...',
        },
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
          'data': {
            'sessionId': 's1',
            'version': 2,
            'producer': 'copilot-cli',
            'copilotVersion': '1.0.0',
            'startTime': '2025-01-01T00:00:00Z',
          },
        }),
        SessionEvent.fromJson({
          'id': '2',
          'timestamp': '2025-01-01T00:00:01Z',
          'type': 'assistant.message',
          'data': {'messageId': 'm1', 'content': 'Hi'},
        }),
        SessionEvent.fromJson({
          'id': '3',
          'timestamp': '2025-01-01T00:00:02Z',
          'type': 'session.idle',
        }),
      ];

      final types = <String>[];
      for (final event in events) {
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
