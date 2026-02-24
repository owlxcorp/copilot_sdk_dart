import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:test/test.dart';

/// Tests for ALL 25 session event types to ensure complete coverage.
void main() {
  Map<String, dynamic> base(String type,
      [Map<String, dynamic> extra = const {}]) {
    return {
      'type': type,
      'id': 'evt-1',
      'timestamp': '2025-01-01T00:00:00Z',
      ...extra,
    };
  }

  // ── Session Lifecycle Events ──────────────────────────────────────────

  group('Session Lifecycle Events', () {
    test('SessionStartEvent parses all fields', () {
      final event = SessionEvent.fromJson(base('session.start', {
        'sessionId': 's-1',
        'version': 2,
        'producer': 'copilot-cli',
        'parentId': 'p-1',
        'ephemeral': true,
      }));

      expect(event, isA<SessionStartEvent>());
      final e = event as SessionStartEvent;
      expect(e.sessionId, 's-1');
      expect(e.version, 2);
      expect(e.producer, 'copilot-cli');
      expect(e.parentId, 'p-1');
      expect(e.ephemeral, isTrue);
      expect(e.type, 'session.start');
    });

    test('SessionStartEvent with minimal fields', () {
      final event = SessionEvent.fromJson(base('session.start', {
        'sessionId': 's-2',
      }));

      final e = event as SessionStartEvent;
      expect(e.sessionId, 's-2');
      expect(e.version, isNull);
      expect(e.producer, isNull);
      expect(e.parentId, isNull);
      expect(e.ephemeral, isFalse);
    });

    test('SessionResumeEvent', () {
      final event = SessionEvent.fromJson(base('session.resume', {
        'sessionId': 's-1',
        'version': 2,
        'producer': 'copilot-cli',
      }));

      expect(event, isA<SessionResumeEvent>());
      final e = event as SessionResumeEvent;
      expect(e.sessionId, 's-1');
      expect(e.version, 2);
      expect(e.producer, 'copilot-cli');
    });

    test('SessionErrorEvent', () {
      final event = SessionEvent.fromJson(base('session.error', {
        'error': 'Rate limit exceeded',
        'code': 'RATE_LIMIT',
      }));

      expect(event, isA<SessionErrorEvent>());
      final e = event as SessionErrorEvent;
      expect(e.error, 'Rate limit exceeded');
      expect(e.code, 'RATE_LIMIT');
    });

    test('SessionErrorEvent without code', () {
      final event = SessionEvent.fromJson(base('session.error', {
        'error': 'Generic error',
      }));

      final e = event as SessionErrorEvent;
      expect(e.code, isNull);
    });

    test('SessionIdleEvent', () {
      final event = SessionEvent.fromJson(base('session.idle', {
        'reason': 'turn_complete',
      }));

      expect(event, isA<SessionIdleEvent>());
      final e = event as SessionIdleEvent;
      expect(e.reason, 'turn_complete');
    });

    test('SessionIdleEvent without reason', () {
      final event = SessionEvent.fromJson(base('session.idle'));

      final e = event as SessionIdleEvent;
      expect(e.reason, isNull);
    });

    test('SessionShutdownEvent', () {
      final event = SessionEvent.fromJson(base('session.shutdown', {
        'reason': 'user_requested',
      }));

      expect(event, isA<SessionShutdownEvent>());
      final e = event as SessionShutdownEvent;
      expect(e.reason, 'user_requested');
    });

    test('SessionShutdownEvent without reason', () {
      final event = SessionEvent.fromJson(base('session.shutdown'));

      final e = event as SessionShutdownEvent;
      expect(e.reason, isNull);
    });

    test('SessionTitleChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.title_changed', {
        'title': 'My Cool Session',
      }));

      expect(event, isA<SessionTitleChangedEvent>());
      final e = event as SessionTitleChangedEvent;
      expect(e.title, 'My Cool Session');
    });

    test('SessionModelChangeEvent', () {
      final event = SessionEvent.fromJson(base('session.model_change', {
        'modelId': 'claude-sonnet',
        'modelName': 'Claude Sonnet',
      }));

      expect(event, isA<SessionModelChangeEvent>());
      final e = event as SessionModelChangeEvent;
      expect(e.modelId, 'claude-sonnet');
      expect(e.modelName, 'Claude Sonnet');
    });

    test('SessionModelChangeEvent without modelName', () {
      final event = SessionEvent.fromJson(base('session.model_change', {
        'modelId': 'gpt-4',
      }));

      final e = event as SessionModelChangeEvent;
      expect(e.modelName, isNull);
    });

    test('SessionModeChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.mode_changed', {
        'mode': 'autopilot',
      }));

      expect(event, isA<SessionModeChangedEvent>());
      final e = event as SessionModeChangedEvent;
      expect(e.mode, 'autopilot');
    });

    test('SessionPlanChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.plan_changed', {
        'plan': '# New Plan\n- Step 1',
      }));

      expect(event, isA<SessionPlanChangedEvent>());
      final e = event as SessionPlanChangedEvent;
      expect(e.plan, '# New Plan\n- Step 1');
    });

    test('SessionPlanChangedEvent with null plan', () {
      final event = SessionEvent.fromJson(base('session.plan_changed'));

      final e = event as SessionPlanChangedEvent;
      expect(e.plan, isNull);
    });

    test('SessionTruncationEvent', () {
      final event = SessionEvent.fromJson(base('session.truncation', {
        'removedCount': 5,
        'remainingCount': 15,
      }));

      expect(event, isA<SessionTruncationEvent>());
      final e = event as SessionTruncationEvent;
      expect(e.removedCount, 5);
      expect(e.remainingCount, 15);
    });

    test('SessionTruncationEvent with null counts', () {
      final event = SessionEvent.fromJson(base('session.truncation'));

      final e = event as SessionTruncationEvent;
      expect(e.removedCount, isNull);
      expect(e.remainingCount, isNull);
    });
  });

  // ── Message Events ────────────────────────────────────────────────────

  group('Message Events', () {
    test('AssistantMessageEvent', () {
      final event = SessionEvent.fromJson(base('assistant.message', {
        'content': 'Hello, how can I help?',
        'role': 'assistant',
      }));

      expect(event, isA<AssistantMessageEvent>());
      final e = event as AssistantMessageEvent;
      expect(e.content, 'Hello, how can I help?');
      expect(e.role, 'assistant');
    });

    test('AssistantMessageEvent without role', () {
      final event = SessionEvent.fromJson(base('assistant.message', {
        'content': 'Hello',
      }));

      final e = event as AssistantMessageEvent;
      expect(e.role, isNull);
    });

    test('AssistantThinkingEvent', () {
      final event = SessionEvent.fromJson(base('assistant.thinking', {
        'content': 'Let me think about this...',
      }));

      expect(event, isA<AssistantThinkingEvent>());
      final e = event as AssistantThinkingEvent;
      expect(e.content, 'Let me think about this...');
    });

    test('UserMessageEvent', () {
      final event = SessionEvent.fromJson(base('user.message', {
        'content': 'What is 2+2?',
      }));

      expect(event, isA<UserMessageEvent>());
      final e = event as UserMessageEvent;
      expect(e.content, 'What is 2+2?');
    });

    test('SystemMessageEvent', () {
      final event = SessionEvent.fromJson(base('system.message', {
        'content': 'You are a helpful assistant.',
      }));

      expect(event, isA<SystemMessageEvent>());
      final e = event as SystemMessageEvent;
      expect(e.content, 'You are a helpful assistant.');
    });
  });

  // ── Tool Events ───────────────────────────────────────────────────────

  group('Tool Events', () {
    test('ToolCallEvent', () {
      final event = SessionEvent.fromJson(base('tool.call', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
        'arguments': {'command': 'ls'},
      }));

      expect(event, isA<ToolCallEvent>());
      final e = event as ToolCallEvent;
      expect(e.toolName, 'bash');
      expect(e.toolCallId, 'tc-1');
      expect(e.arguments, {'command': 'ls'});
    });

    test('ToolCallEvent without arguments', () {
      final event = SessionEvent.fromJson(base('tool.call', {
        'toolName': 'list_tools',
        'toolCallId': 'tc-2',
      }));

      final e = event as ToolCallEvent;
      expect(e.arguments, isNull);
    });

    test('ToolExecutionStartEvent', () {
      final event = SessionEvent.fromJson(base('tool.execution_start', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
      }));

      expect(event, isA<ToolExecutionStartEvent>());
      final e = event as ToolExecutionStartEvent;
      expect(e.toolName, 'bash');
      expect(e.toolCallId, 'tc-1');
    });

    test('ToolExecutionPartialResultEvent', () {
      final event =
          SessionEvent.fromJson(base('tool.execution_partial_result', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
        'partialResult': 'partial output line...',
      }));

      expect(event, isA<ToolExecutionPartialResultEvent>());
      final e = event as ToolExecutionPartialResultEvent;
      expect(e.toolName, 'bash');
      expect(e.toolCallId, 'tc-1');
      expect(e.partialResult, 'partial output line...');
    });

    test('ToolExecutionCompleteEvent', () {
      final event = SessionEvent.fromJson(base('tool.execution_complete', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
        'result': 'total 5\ndrwxr-xr-x  2 user  staff  68 Jan  1 00:00 .',
      }));

      expect(event, isA<ToolExecutionCompleteEvent>());
      final e = event as ToolExecutionCompleteEvent;
      expect(e.toolName, 'bash');
      expect(e.toolCallId, 'tc-1');
      expect(e.result, contains('total 5'));
    });

    test('ToolExecutionCompleteEvent without result', () {
      final event = SessionEvent.fromJson(base('tool.execution_complete', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
      }));

      final e = event as ToolExecutionCompleteEvent;
      expect(e.result, isNull);
    });
  });

  // ── Skill & Sub-agent Events ──────────────────────────────────────────

  group('Skill & Sub-agent Events', () {
    test('SkillInvokedEvent', () {
      final event = SessionEvent.fromJson(base('skill.invoked', {
        'skillName': 'code-review',
        'reason': 'User requested code review',
      }));

      expect(event, isA<SkillInvokedEvent>());
      final e = event as SkillInvokedEvent;
      expect(e.skillName, 'code-review');
      expect(e.reason, 'User requested code review');
    });

    test('SkillInvokedEvent without reason', () {
      final event = SessionEvent.fromJson(base('skill.invoked', {
        'skillName': 'test',
      }));

      final e = event as SkillInvokedEvent;
      expect(e.reason, isNull);
    });

    test('SubagentStartedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.started', {
        'agentId': 'agent-1',
        'agentName': 'code-runner',
      }));

      expect(event, isA<SubagentStartedEvent>());
      final e = event as SubagentStartedEvent;
      expect(e.agentId, 'agent-1');
      expect(e.agentName, 'code-runner');
    });

    test('SubagentCompletedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.completed', {
        'agentId': 'agent-1',
        'agentName': 'code-runner',
        'result': 'Task completed successfully',
      }));

      expect(event, isA<SubagentCompletedEvent>());
      final e = event as SubagentCompletedEvent;
      expect(e.agentId, 'agent-1');
      expect(e.agentName, 'code-runner');
      expect(e.result, 'Task completed successfully');
    });

    test('SubagentCompletedEvent without result', () {
      final event = SessionEvent.fromJson(base('subagent.completed', {
        'agentId': 'agent-1',
      }));

      final e = event as SubagentCompletedEvent;
      expect(e.result, isNull);
      expect(e.agentName, isNull);
    });

    test('SubagentFailedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.failed', {
        'agentId': 'agent-2',
        'agentName': 'deployer',
        'error': 'Deployment failed: insufficient permissions',
      }));

      expect(event, isA<SubagentFailedEvent>());
      final e = event as SubagentFailedEvent;
      expect(e.agentId, 'agent-2');
      expect(e.agentName, 'deployer');
      expect(e.error, contains('insufficient permissions'));
    });

    test('SubagentFailedEvent without error', () {
      final event = SessionEvent.fromJson(base('subagent.failed', {
        'agentId': 'agent-2',
      }));

      final e = event as SubagentFailedEvent;
      expect(e.error, isNull);
    });

    test('SubagentSelectedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.selected', {
        'agentId': 'agent-3',
        'agentName': 'analyzer',
      }));

      expect(event, isA<SubagentSelectedEvent>());
      final e = event as SubagentSelectedEvent;
      expect(e.agentId, 'agent-3');
      expect(e.agentName, 'analyzer');
    });

    test('SubagentSelectedEvent without agentName', () {
      final event = SessionEvent.fromJson(base('subagent.selected', {
        'agentId': 'agent-3',
      }));

      final e = event as SubagentSelectedEvent;
      expect(e.agentName, isNull);
    });
  });

  // ── Hook Events ───────────────────────────────────────────────────────

  group('Hook Events', () {
    test('HookStartEvent', () {
      final event = SessionEvent.fromJson(base('hook.start', {
        'hookType': 'preToolUse',
      }));

      expect(event, isA<HookStartEvent>());
      final e = event as HookStartEvent;
      expect(e.hookType, 'preToolUse');
    });

    test('HookEndEvent', () {
      final event = SessionEvent.fromJson(base('hook.end', {
        'hookType': 'preToolUse',
        'result': {'decision': 'approve'},
      }));

      expect(event, isA<HookEndEvent>());
      final e = event as HookEndEvent;
      expect(e.hookType, 'preToolUse');
      expect(e.result, {'decision': 'approve'});
    });

    test('HookEndEvent without result', () {
      final event = SessionEvent.fromJson(base('hook.end', {
        'hookType': 'sessionStart',
      }));

      final e = event as HookEndEvent;
      expect(e.result, isNull);
    });
  });

  // ── Unknown Events ────────────────────────────────────────────────────

  group('Unknown Events', () {
    test('unknown type produces UnknownEvent', () {
      final event = SessionEvent.fromJson(base('some.future.event', {
        'customField': 'customValue',
      }));

      expect(event, isA<UnknownEvent>());
      final e = event as UnknownEvent;
      expect(e.type, 'some.future.event');
      expect(e.data['customField'], 'customValue');
    });

    test('UnknownEvent preserves all raw data', () {
      final json = base('new.type', {
        'field1': 'a',
        'field2': 42,
        'field3': [1, 2, 3],
      });
      final event = SessionEvent.fromJson(json) as UnknownEvent;

      expect(event.data['field1'], 'a');
      expect(event.data['field2'], 42);
      expect(event.data['field3'], [1, 2, 3]);
    });
  });

  // ── Base Fields ───────────────────────────────────────────────────────

  group('Base Fields', () {
    test('all events have id, timestamp, type', () {
      final event = SessionEvent.fromJson({
        'type': 'session.idle',
        'id': 'unique-id',
        'timestamp': '2025-06-15T12:30:00Z',
      });

      expect(event.id, 'unique-id');
      expect(event.timestamp, '2025-06-15T12:30:00Z');
      expect(event.type, 'session.idle');
    });

    test('parentId and ephemeral default correctly', () {
      final event = SessionEvent.fromJson(base('session.idle'));

      expect(event.parentId, isNull);
      expect(event.ephemeral, isFalse);
    });

    test('parentId and ephemeral are parsed when present', () {
      final event = SessionEvent.fromJson(base('session.idle', {
        'parentId': 'parent-1',
        'ephemeral': true,
      }));

      expect(event.parentId, 'parent-1');
      expect(event.ephemeral, isTrue);
    });
  });

  // ── Exhaustive Pattern Matching ───────────────────────────────────────

  group('Exhaustive Pattern Matching', () {
    test('switch expression covers all 25 event types + unknown', () {
      final events = <SessionEvent>[
        SessionEvent.fromJson(base('session.start', {'sessionId': 's'})),
        SessionEvent.fromJson(base('session.resume', {'sessionId': 's'})),
        SessionEvent.fromJson(base('session.error', {'error': 'e'})),
        SessionEvent.fromJson(base('session.idle')),
        SessionEvent.fromJson(base('session.shutdown')),
        SessionEvent.fromJson(base('session.title_changed', {'title': 't'})),
        SessionEvent.fromJson(base('session.model_change', {'modelId': 'm'})),
        SessionEvent.fromJson(base('session.mode_changed', {'mode': 'm'})),
        SessionEvent.fromJson(base('session.plan_changed')),
        SessionEvent.fromJson(base('session.truncation')),
        SessionEvent.fromJson(base('assistant.message', {'content': 'c'})),
        SessionEvent.fromJson(base('assistant.thinking', {'content': 'c'})),
        SessionEvent.fromJson(base('user.message', {'content': 'c'})),
        SessionEvent.fromJson(base('system.message', {'content': 'c'})),
        SessionEvent.fromJson(
            base('tool.call', {'toolName': 't', 'toolCallId': 'tc'})),
        SessionEvent.fromJson(base(
            'tool.execution_start', {'toolName': 't', 'toolCallId': 'tc'})),
        SessionEvent.fromJson(base('tool.execution_partial_result',
            {'toolName': 't', 'toolCallId': 'tc', 'partialResult': 'r'})),
        SessionEvent.fromJson(base(
            'tool.execution_complete', {'toolName': 't', 'toolCallId': 'tc'})),
        SessionEvent.fromJson(base('skill.invoked', {'skillName': 's'})),
        SessionEvent.fromJson(base('subagent.started', {'agentId': 'a'})),
        SessionEvent.fromJson(base('subagent.completed', {'agentId': 'a'})),
        SessionEvent.fromJson(base('subagent.failed', {'agentId': 'a'})),
        SessionEvent.fromJson(base('subagent.selected', {'agentId': 'a'})),
        SessionEvent.fromJson(base('hook.start', {'hookType': 'h'})),
        SessionEvent.fromJson(base('hook.end', {'hookType': 'h'})),
        SessionEvent.fromJson(base('unknown.type')),
      ];

      for (final event in events) {
        // This switch is exhaustive due to sealed class
        final typeName = switch (event) {
          SessionStartEvent() => 'SessionStartEvent',
          SessionResumeEvent() => 'SessionResumeEvent',
          SessionErrorEvent() => 'SessionErrorEvent',
          SessionIdleEvent() => 'SessionIdleEvent',
          SessionShutdownEvent() => 'SessionShutdownEvent',
          SessionTitleChangedEvent() => 'SessionTitleChangedEvent',
          SessionModelChangeEvent() => 'SessionModelChangeEvent',
          SessionModeChangedEvent() => 'SessionModeChangedEvent',
          SessionPlanChangedEvent() => 'SessionPlanChangedEvent',
          SessionTruncationEvent() => 'SessionTruncationEvent',
          AssistantMessageEvent() => 'AssistantMessageEvent',
          AssistantThinkingEvent() => 'AssistantThinkingEvent',
          UserMessageEvent() => 'UserMessageEvent',
          SystemMessageEvent() => 'SystemMessageEvent',
          ToolCallEvent() => 'ToolCallEvent',
          ToolExecutionStartEvent() => 'ToolExecutionStartEvent',
          ToolExecutionPartialResultEvent() =>
            'ToolExecutionPartialResultEvent',
          ToolExecutionCompleteEvent() => 'ToolExecutionCompleteEvent',
          SkillInvokedEvent() => 'SkillInvokedEvent',
          SubagentStartedEvent() => 'SubagentStartedEvent',
          SubagentCompletedEvent() => 'SubagentCompletedEvent',
          SubagentFailedEvent() => 'SubagentFailedEvent',
          SubagentSelectedEvent() => 'SubagentSelectedEvent',
          HookStartEvent() => 'HookStartEvent',
          HookEndEvent() => 'HookEndEvent',
          UnknownEvent() => 'UnknownEvent',
        };

        expect(typeName, isNotEmpty);
      }

      expect(events.length, 26); // 25 known + 1 unknown
    });
  });
}
