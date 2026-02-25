import 'package:copilot_sdk_dart/src/types/session_event.dart';
import 'package:test/test.dart';

/// Tests for ALL 45 typed session event types + UnknownEvent (46 total).
void main() {
  Map<String, dynamic> base(String type,
      [Map<String, dynamic> data = const {}]) {
    return {
      'type': type,
      'id': 'evt-1',
      'timestamp': '2025-01-01T00:00:00Z',
      'data': data,
    };
  }

  // ── Session Lifecycle Events ──────────────────────────────────────────

  group('Session Lifecycle Events', () {
    test('SessionStartEvent parses all fields', () {
      final event = SessionEvent.fromJson(base('session.start', {
        'sessionId': 's-1',
        'version': 2,
        'producer': 'copilot-cli',
        'copilotVersion': '1.0.0',
        'startTime': '2025-01-01T00:00:00Z',
        'selectedModel': 'gpt-4',
        'context': {'cwd': '/home'},
      }));

      expect(event, isA<SessionStartEvent>());
      final e = event as SessionStartEvent;
      expect(e.sessionId, 's-1');
      expect(e.version, 2);
      expect(e.producer, 'copilot-cli');
      expect(e.copilotVersion, '1.0.0');
      expect(e.startTime, '2025-01-01T00:00:00Z');
      expect(e.selectedModel, 'gpt-4');
      expect(e.context, {'cwd': '/home'});
      expect(e.type, 'session.start');
    });

    test('SessionStartEvent with required fields only', () {
      final event = SessionEvent.fromJson(base('session.start', {
        'sessionId': 's-2',
        'version': 2,
        'producer': 'copilot-cli',
        'copilotVersion': '1.0.0',
        'startTime': '2025-01-01T00:00:00Z',
      }));

      final e = event as SessionStartEvent;
      expect(e.sessionId, 's-2');
      expect(e.version, 2);
      expect(e.producer, 'copilot-cli');
      expect(e.copilotVersion, '1.0.0');
      expect(e.selectedModel, isNull);
      expect(e.context, isNull);
    });

    test('SessionStartEvent flat format (backward compat)', () {
      final event = SessionEvent.fromJson({
        'type': 'session.start',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'sessionId': 's-flat',
        'version': 1,
        'producer': 'test',
        'copilotVersion': '0.1',
        'startTime': '2025-01-01T00:00:00Z',
        'parentId': 'p-1',
        'ephemeral': true,
      });

      final e = event as SessionStartEvent;
      expect(e.sessionId, 's-flat');
      expect(e.parentId, 'p-1');
      expect(e.ephemeral, isTrue);
    });

    test('SessionResumeEvent', () {
      final event = SessionEvent.fromJson(base('session.resume', {
        'resumeTime': '2025-01-01T01:00:00Z',
        'eventCount': 42,
        'context': {'cwd': '/home'},
      }));

      expect(event, isA<SessionResumeEvent>());
      final e = event as SessionResumeEvent;
      expect(e.resumeTime, '2025-01-01T01:00:00Z');
      expect(e.eventCount, 42);
      expect(e.context, {'cwd': '/home'});
    });

    test('SessionResumeEvent requires resumeTime and eventCount', () {
      expect(
        () => SessionEvent.fromJson(base('session.resume')),
        throwsA(isA<FormatException>()),
      );
    });

    test('SessionErrorEvent', () {
      final event = SessionEvent.fromJson(base('session.error', {
        'errorType': 'provider_error',
        'message': 'Rate limit exceeded',
        'stack': 'Error at line 1',
        'statusCode': 429,
        'providerCallId': 'pc-1',
      }));

      expect(event, isA<SessionErrorEvent>());
      final e = event as SessionErrorEvent;
      expect(e.errorType, 'provider_error');
      expect(e.message, 'Rate limit exceeded');
      expect(e.stack, 'Error at line 1');
      expect(e.statusCode, 429);
      expect(e.providerCallId, 'pc-1');
    });

    test('SessionErrorEvent requires errorType and message', () {
      expect(
        () => SessionEvent.fromJson(base('session.error')),
        throwsA(isA<FormatException>()),
      );
    });

    test('SessionIdleEvent', () {
      final event = SessionEvent.fromJson(base('session.idle'));

      expect(event, isA<SessionIdleEvent>());
      // SessionIdleEvent defaults ephemeral to true
      expect(event.ephemeral, isTrue);
    });

    test('SessionTitleChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.title_changed', {
        'title': 'My Cool Session',
      }));

      expect(event, isA<SessionTitleChangedEvent>());
      final e = event as SessionTitleChangedEvent;
      expect(e.title, 'My Cool Session');
    });

    test('SessionInfoEvent', () {
      final event = SessionEvent.fromJson(base('session.info', {
        'infoType': 'context',
        'message': 'Working directory changed',
      }));

      expect(event, isA<SessionInfoEvent>());
      final e = event as SessionInfoEvent;
      expect(e.infoType, 'context');
      expect(e.message, 'Working directory changed');
    });

    test('SessionWarningEvent', () {
      final event = SessionEvent.fromJson(base('session.warning', {
        'warningType': 'quota',
        'message': 'Low quota remaining',
      }));

      expect(event, isA<SessionWarningEvent>());
      final e = event as SessionWarningEvent;
      expect(e.warningType, 'quota');
      expect(e.message, 'Low quota remaining');
    });

    test('SessionModelChangeEvent', () {
      final event = SessionEvent.fromJson(base('session.model_change', {
        'previousModel': 'gpt-4',
        'newModel': 'claude-sonnet',
      }));

      expect(event, isA<SessionModelChangeEvent>());
      final e = event as SessionModelChangeEvent;
      expect(e.previousModel, 'gpt-4');
      expect(e.newModel, 'claude-sonnet');
    });

    test('SessionModelChangeEvent without previousModel', () {
      final event = SessionEvent.fromJson(base('session.model_change', {
        'newModel': 'gpt-4',
      }));

      final e = event as SessionModelChangeEvent;
      expect(e.previousModel, isNull);
      expect(e.newModel, 'gpt-4');
    });

    test('SessionModeChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.mode_changed', {
        'previousMode': 'interactive',
        'newMode': 'autopilot',
      }));

      expect(event, isA<SessionModeChangedEvent>());
      final e = event as SessionModeChangedEvent;
      expect(e.previousMode, 'interactive');
      expect(e.newMode, 'autopilot');
    });

    test('SessionPlanChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.plan_changed', {
        'operation': 'create',
      }));

      expect(event, isA<SessionPlanChangedEvent>());
      final e = event as SessionPlanChangedEvent;
      expect(e.operation, 'create');
    });

    test('SessionPlanChangedEvent with default operation', () {
      final event = SessionEvent.fromJson(base('session.plan_changed'));

      final e = event as SessionPlanChangedEvent;
      expect(e.operation, '');
    });

    test('SessionWorkspaceFileChangedEvent', () {
      final event =
          SessionEvent.fromJson(base('session.workspace_file_changed', {
        'path': 'plan.md',
        'operation': 'update',
      }));

      expect(event, isA<SessionWorkspaceFileChangedEvent>());
      final e = event as SessionWorkspaceFileChangedEvent;
      expect(e.path, 'plan.md');
      expect(e.operation, 'update');
    });

    test('SessionHandoffEvent', () {
      final event = SessionEvent.fromJson(base('session.handoff', {
        'handoffTime': '2025-01-01T00:00:00Z',
        'sourceType': 'remote',
        'repository': {'owner': 'test', 'name': 'repo'},
        'context': 'some context',
        'summary': 'Session summary',
        'remoteSessionId': 'rs-1',
      }));

      expect(event, isA<SessionHandoffEvent>());
      final e = event as SessionHandoffEvent;
      expect(e.handoffTime, '2025-01-01T00:00:00Z');
      expect(e.sourceType, 'remote');
      expect(e.repository, {'owner': 'test', 'name': 'repo'});
      expect(e.summary, 'Session summary');
      expect(e.remoteSessionId, 'rs-1');
    });

    test('SessionTruncationEvent', () {
      final event = SessionEvent.fromJson(base('session.truncation', {
        'tokenLimit': 128000,
        'preTruncationTokensInMessages': 130000,
        'preTruncationMessagesLength': 50,
        'postTruncationTokensInMessages': 100000,
        'postTruncationMessagesLength': 35,
        'tokensRemovedDuringTruncation': 30000,
        'messagesRemovedDuringTruncation': 15,
        'performedBy': 'system',
      }));

      expect(event, isA<SessionTruncationEvent>());
      final e = event as SessionTruncationEvent;
      expect(e.tokenLimit, 128000);
      expect(e.preTruncationTokensInMessages, 130000);
      expect(e.preTruncationMessagesLength, 50);
      expect(e.postTruncationTokensInMessages, 100000);
      expect(e.postTruncationMessagesLength, 35);
      expect(e.tokensRemovedDuringTruncation, 30000);
      expect(e.messagesRemovedDuringTruncation, 15);
      expect(e.performedBy, 'system');
    });

    test('SessionTruncationEvent with defaults', () {
      final event = SessionEvent.fromJson(base('session.truncation'));

      final e = event as SessionTruncationEvent;
      expect(e.tokenLimit, 0);
      expect(e.performedBy, '');
    });

    test('SessionSnapshotRewindEvent', () {
      final event = SessionEvent.fromJson(base('session.snapshot_rewind', {
        'upToEventId': 'evt-100',
        'eventsRemoved': 5,
      }));

      expect(event, isA<SessionSnapshotRewindEvent>());
      final e = event as SessionSnapshotRewindEvent;
      expect(e.upToEventId, 'evt-100');
      expect(e.eventsRemoved, 5);
    });

    test('SessionShutdownEvent', () {
      final event = SessionEvent.fromJson(base('session.shutdown', {
        'shutdownType': 'routine',
        'totalPremiumRequests': 10,
        'totalApiDurationMs': 5000,
        'sessionStartTime': 1704067200,
        'currentModel': 'gpt-4',
        'codeChanges': {'filesChanged': 3},
        'modelMetrics': {'calls': 5},
      }));

      expect(event, isA<SessionShutdownEvent>());
      final e = event as SessionShutdownEvent;
      expect(e.shutdownType, 'routine');
      expect(e.errorReason, isNull);
      expect(e.totalPremiumRequests, 10);
      expect(e.totalApiDurationMs, 5000);
      expect(e.sessionStartTime, 1704067200);
      expect(e.currentModel, 'gpt-4');
      expect(e.codeChanges, {'filesChanged': 3});
      expect(e.modelMetrics, {'calls': 5});
    });

    test('SessionShutdownEvent with defaults', () {
      final event = SessionEvent.fromJson(base('session.shutdown'));

      final e = event as SessionShutdownEvent;
      expect(e.shutdownType, 'routine');
      expect(e.totalPremiumRequests, 0);
    });

    test('SessionContextChangedEvent', () {
      final event = SessionEvent.fromJson(base('session.context_changed', {
        'cwd': '/home/user/project',
        'gitRoot': '/home/user/project',
        'repository': 'owner/repo',
        'branch': 'main',
      }));

      expect(event, isA<SessionContextChangedEvent>());
      final e = event as SessionContextChangedEvent;
      expect(e.cwd, '/home/user/project');
      expect(e.gitRoot, '/home/user/project');
      expect(e.repository, 'owner/repo');
      expect(e.branch, 'main');
    });

    test('SessionUsageInfoEvent', () {
      final event = SessionEvent.fromJson(base('session.usage_info', {
        'tokenLimit': 128000,
        'currentTokens': 5000,
        'messagesLength': 12,
      }));

      expect(event, isA<SessionUsageInfoEvent>());
      final e = event as SessionUsageInfoEvent;
      expect(e.tokenLimit, 128000);
      expect(e.currentTokens, 5000);
      expect(e.messagesLength, 12);
    });

    test('SessionCompactionStartEvent', () {
      final event = SessionEvent.fromJson(base('session.compaction_start'));

      expect(event, isA<SessionCompactionStartEvent>());
    });

    test('SessionCompactionCompleteEvent', () {
      final event = SessionEvent.fromJson(base('session.compaction_complete', {
        'success': true,
        'preCompactionTokens': 130000,
        'postCompactionTokens': 80000,
        'preCompactionMessagesLength': 50,
        'messagesRemoved': 20,
        'tokensRemoved': 50000,
        'summaryContent': 'Summary of session so far',
        'checkpointNumber': 3,
        'checkpointPath': '/path/to/checkpoint',
      }));

      expect(event, isA<SessionCompactionCompleteEvent>());
      final e = event as SessionCompactionCompleteEvent;
      expect(e.success, isTrue);
      expect(e.preCompactionTokens, 130000);
      expect(e.postCompactionTokens, 80000);
      expect(e.messagesRemoved, 20);
      expect(e.checkpointNumber, 3);
    });

    test('SessionCompactionCompleteEvent with failure', () {
      final event = SessionEvent.fromJson(base('session.compaction_complete', {
        'success': false,
        'error': 'Compaction failed',
      }));

      final e = event as SessionCompactionCompleteEvent;
      expect(e.success, isFalse);
      expect(e.error, 'Compaction failed');
    });

    test('SessionTaskCompleteEvent', () {
      final event = SessionEvent.fromJson(base('session.task_complete', {
        'summary': 'All tasks done',
      }));

      expect(event, isA<SessionTaskCompleteEvent>());
      final e = event as SessionTaskCompleteEvent;
      expect(e.summary, 'All tasks done');
    });

    test('SessionTaskCompleteEvent without summary', () {
      final event = SessionEvent.fromJson(base('session.task_complete'));

      final e = event as SessionTaskCompleteEvent;
      expect(e.summary, isNull);
    });
  });

  // ── Message Events ────────────────────────────────────────────────────

  group('Message Events', () {
    test('UserMessageEvent', () {
      final event = SessionEvent.fromJson(base('user.message', {
        'content': 'What is 2+2?',
        'transformedContent': 'What is 2+2? (with context)',
        'source': 'cli',
        'agentMode': 'autopilot',
      }));

      expect(event, isA<UserMessageEvent>());
      final e = event as UserMessageEvent;
      expect(e.content, 'What is 2+2?');
      expect(e.transformedContent, 'What is 2+2? (with context)');
      expect(e.source, 'cli');
      expect(e.agentMode, 'autopilot');
    });

    test('PendingMessagesModifiedEvent', () {
      final event = SessionEvent.fromJson(base('pending_messages.modified'));

      expect(event, isA<PendingMessagesModifiedEvent>());
      expect(event.ephemeral, isTrue);
    });

    test('AssistantTurnStartEvent', () {
      final event = SessionEvent.fromJson(base('assistant.turn_start', {
        'turnId': 'turn-1',
      }));

      expect(event, isA<AssistantTurnStartEvent>());
      final e = event as AssistantTurnStartEvent;
      expect(e.turnId, 'turn-1');
    });

    test('AssistantIntentEvent', () {
      final event = SessionEvent.fromJson(base('assistant.intent', {
        'intent': 'Exploring codebase',
      }));

      expect(event, isA<AssistantIntentEvent>());
      final e = event as AssistantIntentEvent;
      expect(e.intent, 'Exploring codebase');
    });

    test('AssistantReasoningEvent', () {
      final event = SessionEvent.fromJson(base('assistant.reasoning', {
        'reasoningId': 'r-1',
        'content': 'Let me think about this...',
      }));

      expect(event, isA<AssistantReasoningEvent>());
      final e = event as AssistantReasoningEvent;
      expect(e.reasoningId, 'r-1');
      expect(e.content, 'Let me think about this...');
    });

    test('AssistantReasoningDeltaEvent', () {
      final event = SessionEvent.fromJson(base('assistant.reasoning_delta', {
        'reasoningId': 'r-1',
        'deltaContent': 'thinking more...',
      }));

      expect(event, isA<AssistantReasoningDeltaEvent>());
      final e = event as AssistantReasoningDeltaEvent;
      expect(e.reasoningId, 'r-1');
      expect(e.deltaContent, 'thinking more...');
    });

    test('AssistantStreamingDeltaEvent', () {
      final event = SessionEvent.fromJson(base('assistant.streaming_delta', {
        'totalResponseSizeBytes': 4096,
      }));

      expect(event, isA<AssistantStreamingDeltaEvent>());
      final e = event as AssistantStreamingDeltaEvent;
      expect(e.totalResponseSizeBytes, 4096);
    });

    test('AssistantMessageEvent', () {
      final event = SessionEvent.fromJson(base('assistant.message', {
        'messageId': 'msg-1',
        'content': 'Hello, how can I help?',
        'toolRequests': [
          {'toolName': 'bash'},
        ],
        'reasoningText': 'I should greet the user',
        'phase': 'main',
        'parentToolCallId': 'tc-parent',
      }));

      expect(event, isA<AssistantMessageEvent>());
      final e = event as AssistantMessageEvent;
      expect(e.messageId, 'msg-1');
      expect(e.content, 'Hello, how can I help?');
      expect(e.toolRequests, hasLength(1));
      expect(e.reasoningText, 'I should greet the user');
      expect(e.phase, 'main');
      expect(e.parentToolCallId, 'tc-parent');
    });

    test('AssistantMessageEvent requires messageId and content', () {
      expect(
        () => SessionEvent.fromJson(base('assistant.message')),
        throwsA(isA<FormatException>()),
      );
    });

    test('AssistantMessageDeltaEvent', () {
      final event = SessionEvent.fromJson(base('assistant.message_delta', {
        'messageId': 'msg-1',
        'deltaContent': 'Hello ',
        'parentToolCallId': 'tc-1',
      }));

      expect(event, isA<AssistantMessageDeltaEvent>());
      final e = event as AssistantMessageDeltaEvent;
      expect(e.messageId, 'msg-1');
      expect(e.deltaContent, 'Hello ');
      expect(e.parentToolCallId, 'tc-1');
    });

    test('AssistantMessageDeltaEvent requires messageId and deltaContent', () {
      expect(
        () => SessionEvent.fromJson(base('assistant.message_delta')),
        throwsA(isA<FormatException>()),
      );
    });

    test('AssistantTurnEndEvent', () {
      final event = SessionEvent.fromJson(base('assistant.turn_end', {
        'turnId': 'turn-1',
      }));

      expect(event, isA<AssistantTurnEndEvent>());
      final e = event as AssistantTurnEndEvent;
      expect(e.turnId, 'turn-1');
    });

    test('AssistantUsageEvent', () {
      final event = SessionEvent.fromJson(base('assistant.usage', {
        'model': 'gpt-4',
        'inputTokens': 100,
        'outputTokens': 200,
        'cacheReadTokens': 50,
        'cost': 0.003,
        'duration': 1.5,
        'initiator': 'main',
        'apiCallId': 'api-1',
        'providerCallId': 'pc-1',
      }));

      expect(event, isA<AssistantUsageEvent>());
      final e = event as AssistantUsageEvent;
      expect(e.model, 'gpt-4');
      expect(e.inputTokens, 100);
      expect(e.outputTokens, 200);
      expect(e.cacheReadTokens, 50);
      expect(e.cost, 0.003);
      expect(e.duration, 1.5);
    });

    test('SystemMessageEvent', () {
      final event = SessionEvent.fromJson(base('system.message', {
        'content': 'You are a helpful assistant.',
        'role': 'developer',
        'name': 'instructions',
        'metadata': {'source': 'config'},
      }));

      expect(event, isA<SystemMessageEvent>());
      final e = event as SystemMessageEvent;
      expect(e.content, 'You are a helpful assistant.');
      expect(e.role, 'developer');
      expect(e.name, 'instructions');
      expect(e.metadata, {'source': 'config'});
    });

    test('SystemMessageEvent with defaults', () {
      final event = SessionEvent.fromJson(base('system.message'));

      final e = event as SystemMessageEvent;
      expect(e.role, 'system');
      expect(e.name, isNull);
      expect(e.metadata, isNull);
    });
  });

  // ── Abort Event ───────────────────────────────────────────────────────

  group('Abort Event', () {
    test('AbortEvent', () {
      final event = SessionEvent.fromJson(base('abort', {
        'reason': 'user_requested',
      }));

      expect(event, isA<AbortEvent>());
      final e = event as AbortEvent;
      expect(e.reason, 'user_requested');
    });
  });

  // ── Tool Events ───────────────────────────────────────────────────────

  group('Tool Events', () {
    test('ToolUserRequestedEvent', () {
      final event = SessionEvent.fromJson(base('tool.user_requested', {
        'toolCallId': 'tc-1',
        'toolName': 'bash',
        'arguments': {'command': 'ls'},
      }));

      expect(event, isA<ToolUserRequestedEvent>());
      final e = event as ToolUserRequestedEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.toolName, 'bash');
      expect(e.arguments, {'command': 'ls'});
    });

    test('ToolExecutionStartEvent', () {
      final event = SessionEvent.fromJson(base('tool.execution_start', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
        'arguments': {'command': 'ls'},
        'mcpServerName': 'mcp-server',
        'mcpToolName': 'mcp-bash',
        'parentToolCallId': 'tc-parent',
      }));

      expect(event, isA<ToolExecutionStartEvent>());
      final e = event as ToolExecutionStartEvent;
      expect(e.toolName, 'bash');
      expect(e.toolCallId, 'tc-1');
      expect(e.arguments, {'command': 'ls'});
      expect(e.mcpServerName, 'mcp-server');
      expect(e.mcpToolName, 'mcp-bash');
      expect(e.parentToolCallId, 'tc-parent');
    });

    test('ToolExecutionStartEvent with defaults', () {
      final event = SessionEvent.fromJson(base('tool.execution_start', {
        'toolName': 'bash',
        'toolCallId': 'tc-1',
      }));

      final e = event as ToolExecutionStartEvent;
      expect(e.arguments, isNull);
      expect(e.mcpServerName, isNull);
      expect(e.mcpToolName, isNull);
      expect(e.parentToolCallId, isNull);
    });

    test('ToolExecutionPartialResultEvent', () {
      final event =
          SessionEvent.fromJson(base('tool.execution_partial_result', {
        'toolCallId': 'tc-1',
        'partialOutput': 'partial output line...',
      }));

      expect(event, isA<ToolExecutionPartialResultEvent>());
      final e = event as ToolExecutionPartialResultEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.partialOutput, 'partial output line...');
    });

    test('ToolExecutionProgressEvent', () {
      final event = SessionEvent.fromJson(base('tool.execution_progress', {
        'toolCallId': 'tc-1',
        'progressMessage': 'Running step 2 of 5...',
      }));

      expect(event, isA<ToolExecutionProgressEvent>());
      final e = event as ToolExecutionProgressEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.progressMessage, 'Running step 2 of 5...');
    });

    test('ToolExecutionCompleteEvent with success', () {
      final event = SessionEvent.fromJson(base('tool.execution_complete', {
        'toolCallId': 'tc-1',
        'success': true,
        'isUserRequested': false,
        'result': {'content': 'file contents here'},
        'toolTelemetry': {'durationMs': 150},
        'parentToolCallId': 'tc-parent',
      }));

      expect(event, isA<ToolExecutionCompleteEvent>());
      final e = event as ToolExecutionCompleteEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.success, isTrue);
      expect(e.isUserRequested, isFalse);
      expect(e.result, {'content': 'file contents here'});
      expect(e.error, isNull);
      expect(e.toolTelemetry, {'durationMs': 150});
      expect(e.parentToolCallId, 'tc-parent');
    });

    test('ToolExecutionCompleteEvent with error', () {
      final event = SessionEvent.fromJson(base('tool.execution_complete', {
        'toolCallId': 'tc-1',
        'success': false,
        'error': {'message': 'File not found', 'code': 'ENOENT'},
      }));

      final e = event as ToolExecutionCompleteEvent;
      expect(e.success, isFalse);
      expect(e.error, {'message': 'File not found', 'code': 'ENOENT'});
      expect(e.result, isNull);
    });

    test('ToolExecutionCompleteEvent requires success', () {
      expect(
        () => SessionEvent.fromJson(base('tool.execution_complete', {
          'toolCallId': 'tc-1',
        })),
        throwsA(isA<FormatException>()),
      );
    });

    test('ToolExecutionCompleteEvent with required fields only', () {
      final event = SessionEvent.fromJson(base('tool.execution_complete', {
        'toolCallId': 'tc-1',
        'success': false,
      }));

      final e = event as ToolExecutionCompleteEvent;
      expect(e.success, isFalse);
      expect(e.result, isNull);
      expect(e.error, isNull);
    });
  });

  // ── Skill & Sub-agent Events ──────────────────────────────────────────

  group('Skill & Sub-agent Events', () {
    test('SkillInvokedEvent', () {
      final event = SessionEvent.fromJson(base('skill.invoked', {
        'name': 'code-review',
        'path': '/skills/code-review',
        'content': 'Review this code',
        'allowedTools': ['bash', 'read_file'],
      }));

      expect(event, isA<SkillInvokedEvent>());
      final e = event as SkillInvokedEvent;
      expect(e.name, 'code-review');
      expect(e.path, '/skills/code-review');
      expect(e.content, 'Review this code');
      expect(e.allowedTools, ['bash', 'read_file']);
    });

    test('SkillInvokedEvent with defaults', () {
      final event = SessionEvent.fromJson(base('skill.invoked'));

      final e = event as SkillInvokedEvent;
      expect(e.name, '');
      expect(e.path, '');
      expect(e.content, '');
      expect(e.allowedTools, isNull);
    });

    test('SubagentStartedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.started', {
        'toolCallId': 'tc-1',
        'agentName': 'code-runner',
        'agentDisplayName': 'Code Runner',
        'agentDescription': 'Runs code in sandbox',
      }));

      expect(event, isA<SubagentStartedEvent>());
      final e = event as SubagentStartedEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.agentName, 'code-runner');
      expect(e.agentDisplayName, 'Code Runner');
      expect(e.agentDescription, 'Runs code in sandbox');
    });

    test('SubagentCompletedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.completed', {
        'toolCallId': 'tc-1',
        'agentName': 'code-runner',
        'agentDisplayName': 'Code Runner',
      }));

      expect(event, isA<SubagentCompletedEvent>());
      final e = event as SubagentCompletedEvent;
      expect(e.toolCallId, 'tc-1');
      expect(e.agentName, 'code-runner');
      expect(e.agentDisplayName, 'Code Runner');
    });

    test('SubagentFailedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.failed', {
        'toolCallId': 'tc-2',
        'agentName': 'deployer',
        'agentDisplayName': 'Deployer',
        'error': 'Deployment failed: insufficient permissions',
      }));

      expect(event, isA<SubagentFailedEvent>());
      final e = event as SubagentFailedEvent;
      expect(e.toolCallId, 'tc-2');
      expect(e.agentName, 'deployer');
      expect(e.agentDisplayName, 'Deployer');
      expect(e.error, contains('insufficient permissions'));
    });

    test('SubagentSelectedEvent', () {
      final event = SessionEvent.fromJson(base('subagent.selected', {
        'agentName': 'analyzer',
        'agentDisplayName': 'Analyzer',
        'tools': ['read_file', 'grep'],
      }));

      expect(event, isA<SubagentSelectedEvent>());
      final e = event as SubagentSelectedEvent;
      expect(e.agentName, 'analyzer');
      expect(e.agentDisplayName, 'Analyzer');
      expect(e.tools, ['read_file', 'grep']);
    });

    test('SubagentSelectedEvent without tools', () {
      final event = SessionEvent.fromJson(base('subagent.selected', {
        'agentName': 'analyzer',
        'agentDisplayName': 'Analyzer',
      }));

      final e = event as SubagentSelectedEvent;
      expect(e.tools, isNull);
    });
  });

  // ── Hook Events ───────────────────────────────────────────────────────

  group('Hook Events', () {
    test('HookStartEvent', () {
      final event = SessionEvent.fromJson(base('hook.start', {
        'hookInvocationId': 'hi-1',
        'hookType': 'preToolUse',
        'input': {'toolName': 'bash'},
      }));

      expect(event, isA<HookStartEvent>());
      final e = event as HookStartEvent;
      expect(e.hookInvocationId, 'hi-1');
      expect(e.hookType, 'preToolUse');
      expect(e.input, {'toolName': 'bash'});
    });

    test('HookEndEvent with success', () {
      final event = SessionEvent.fromJson(base('hook.end', {
        'hookInvocationId': 'hi-1',
        'hookType': 'preToolUse',
        'output': {'decision': 'approve'},
        'success': true,
      }));

      expect(event, isA<HookEndEvent>());
      final e = event as HookEndEvent;
      expect(e.hookInvocationId, 'hi-1');
      expect(e.hookType, 'preToolUse');
      expect(e.output, {'decision': 'approve'});
      expect(e.success, isTrue);
      expect(e.error, isNull);
    });

    test('HookEndEvent with error', () {
      final event = SessionEvent.fromJson(base('hook.end', {
        'hookInvocationId': 'hi-1',
        'hookType': 'preToolUse',
        'success': false,
        'error': {'message': 'Hook timed out'},
      }));

      final e = event as HookEndEvent;
      expect(e.success, isFalse);
      expect(e.error, {'message': 'Hook timed out'});
    });
  });

  // ── Unknown Events ────────────────────────────────────────────────────

  group('Unknown Events', () {
    test('unknown type produces UnknownEvent', () {
      final event = SessionEvent.fromJson({
        'type': 'some.future.event',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'data': {'customField': 'customValue'},
      });

      expect(event, isA<UnknownEvent>());
      final e = event as UnknownEvent;
      expect(e.type, 'some.future.event');
    });

    test('UnknownEvent preserves raw data', () {
      final json = {
        'type': 'new.type',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'field1': 'a',
        'field2': 42,
      };
      final event = SessionEvent.fromJson(json) as UnknownEvent;

      expect(event.data['field1'], 'a');
      expect(event.data['field2'], 42);
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

    test('parentId and ephemeral are parsed when present', () {
      final event = SessionEvent.fromJson({
        'type': 'session.error',
        'id': 'evt-1',
        'timestamp': '2025-01-01T00:00:00Z',
        'parentId': 'parent-1',
        'ephemeral': true,
        'data': {
          'errorType': 'test',
          'message': 'test error',
        },
      });

      expect(event.parentId, 'parent-1');
      expect(event.ephemeral, isTrue);
    });
  });

  // ── Exhaustive Pattern Matching ───────────────────────────────────────

  group('Exhaustive Pattern Matching', () {
    test('switch expression covers all 45 event types + unknown (46 total)',
        () {
      final events = <SessionEvent>[
        // Session lifecycle (20)
        SessionEvent.fromJson(base('session.start', {
          'sessionId': 's',
          'version': 2,
          'producer': 'copilot-cli',
          'copilotVersion': '1.0.0',
          'startTime': '2025-01-01T00:00:00Z',
        })),
        SessionEvent.fromJson(base('session.resume', {
          'resumeTime': '2025-01-01T00:00:00Z',
          'eventCount': 1,
        })),
        SessionEvent.fromJson(base('session.error', {
          'errorType': 'test',
          'message': 'test',
        })),
        SessionEvent.fromJson(base('session.idle')),
        SessionEvent.fromJson(base('session.title_changed', {'title': 't'})),
        SessionEvent.fromJson(base('session.info')),
        SessionEvent.fromJson(base('session.warning')),
        SessionEvent.fromJson(base('session.model_change', {'newModel': 'm'})),
        SessionEvent.fromJson(base('session.mode_changed')),
        SessionEvent.fromJson(base('session.plan_changed')),
        SessionEvent.fromJson(base('session.workspace_file_changed')),
        SessionEvent.fromJson(base('session.handoff')),
        SessionEvent.fromJson(base('session.truncation')),
        SessionEvent.fromJson(base('session.snapshot_rewind')),
        SessionEvent.fromJson(base('session.shutdown')),
        SessionEvent.fromJson(base('session.context_changed')),
        SessionEvent.fromJson(base('session.usage_info')),
        SessionEvent.fromJson(base('session.compaction_start')),
        SessionEvent.fromJson(base('session.compaction_complete')),
        SessionEvent.fromJson(base('session.task_complete')),
        // Messages (12)
        SessionEvent.fromJson(base('user.message', {'content': 'c'})),
        SessionEvent.fromJson(base('pending_messages.modified')),
        SessionEvent.fromJson(base('assistant.turn_start', {'turnId': 't'})),
        SessionEvent.fromJson(base('assistant.intent')),
        SessionEvent.fromJson(base('assistant.reasoning')),
        SessionEvent.fromJson(base('assistant.reasoning_delta')),
        SessionEvent.fromJson(base('assistant.streaming_delta')),
        SessionEvent.fromJson(
          base('assistant.message', {'messageId': 'm', 'content': 'c'}),
        ),
        SessionEvent.fromJson(
          base('assistant.message_delta',
              {'messageId': 'm', 'deltaContent': 'd'}),
        ),
        SessionEvent.fromJson(base('assistant.turn_end')),
        SessionEvent.fromJson(base('assistant.usage', {'model': 'm'})),
        SessionEvent.fromJson(base('system.message')),
        // Abort (1)
        SessionEvent.fromJson(base('abort')),
        // Tools (5)
        SessionEvent.fromJson(base('tool.user_requested')),
        SessionEvent.fromJson(base('tool.execution_start')),
        SessionEvent.fromJson(base('tool.execution_partial_result')),
        SessionEvent.fromJson(base('tool.execution_progress')),
        SessionEvent.fromJson(
          base(
              'tool.execution_complete', {'toolCallId': 'tc', 'success': true}),
        ),
        // Skills & subagents (4)
        SessionEvent.fromJson(base('skill.invoked')),
        SessionEvent.fromJson(base('subagent.started')),
        SessionEvent.fromJson(base('subagent.completed')),
        SessionEvent.fromJson(base('subagent.failed')),
        SessionEvent.fromJson(base('subagent.selected')),
        // Hooks (2)
        SessionEvent.fromJson(base('hook.start')),
        SessionEvent.fromJson(base('hook.end')),
        // Unknown (1)
        SessionEvent.fromJson({
          'type': 'unknown.type',
          'id': 'evt-1',
          'timestamp': '2025-01-01T00:00:00Z',
        }),
      ];

      for (final event in events) {
        // This switch is exhaustive due to sealed class
        final typeName = switch (event) {
          SessionStartEvent() => 'SessionStartEvent',
          SessionResumeEvent() => 'SessionResumeEvent',
          SessionErrorEvent() => 'SessionErrorEvent',
          SessionIdleEvent() => 'SessionIdleEvent',
          SessionTitleChangedEvent() => 'SessionTitleChangedEvent',
          SessionInfoEvent() => 'SessionInfoEvent',
          SessionWarningEvent() => 'SessionWarningEvent',
          SessionModelChangeEvent() => 'SessionModelChangeEvent',
          SessionModeChangedEvent() => 'SessionModeChangedEvent',
          SessionPlanChangedEvent() => 'SessionPlanChangedEvent',
          SessionWorkspaceFileChangedEvent() =>
            'SessionWorkspaceFileChangedEvent',
          SessionHandoffEvent() => 'SessionHandoffEvent',
          SessionTruncationEvent() => 'SessionTruncationEvent',
          SessionSnapshotRewindEvent() => 'SessionSnapshotRewindEvent',
          SessionShutdownEvent() => 'SessionShutdownEvent',
          SessionContextChangedEvent() => 'SessionContextChangedEvent',
          SessionUsageInfoEvent() => 'SessionUsageInfoEvent',
          SessionCompactionStartEvent() => 'SessionCompactionStartEvent',
          SessionCompactionCompleteEvent() => 'SessionCompactionCompleteEvent',
          SessionTaskCompleteEvent() => 'SessionTaskCompleteEvent',
          UserMessageEvent() => 'UserMessageEvent',
          PendingMessagesModifiedEvent() => 'PendingMessagesModifiedEvent',
          AssistantTurnStartEvent() => 'AssistantTurnStartEvent',
          AssistantIntentEvent() => 'AssistantIntentEvent',
          AssistantReasoningEvent() => 'AssistantReasoningEvent',
          AssistantReasoningDeltaEvent() => 'AssistantReasoningDeltaEvent',
          AssistantStreamingDeltaEvent() => 'AssistantStreamingDeltaEvent',
          AssistantMessageEvent() => 'AssistantMessageEvent',
          AssistantMessageDeltaEvent() => 'AssistantMessageDeltaEvent',
          AssistantTurnEndEvent() => 'AssistantTurnEndEvent',
          AssistantUsageEvent() => 'AssistantUsageEvent',
          SystemMessageEvent() => 'SystemMessageEvent',
          AbortEvent() => 'AbortEvent',
          ToolUserRequestedEvent() => 'ToolUserRequestedEvent',
          ToolExecutionStartEvent() => 'ToolExecutionStartEvent',
          ToolExecutionPartialResultEvent() =>
            'ToolExecutionPartialResultEvent',
          ToolExecutionProgressEvent() => 'ToolExecutionProgressEvent',
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

      expect(events.length, 46); // 45 known + 1 unknown
    });
  });
}
