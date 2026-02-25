import 'package:copilot_sdk_dart/src/types/hooks.dart';
import 'package:test/test.dart';

void main() {
  // ── hasHooks ──────────────────────────────────────────────────────────

  group('hasHooks', () {
    test('returns false when no hooks are set', () {
      const hooks = SessionHooks();

      expect(hooks.hasHooks, isFalse);
    });

    test('returns true when onPreToolUse is set', () {
      final hooks = SessionHooks(
        onPreToolUse: (input, inv) async => const PreToolUseOutput(),
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onPostToolUse is set', () {
      final hooks = SessionHooks(
        onPostToolUse: (input, inv) async => const PostToolUseOutput(),
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onUserPromptSubmitted is set', () {
      final hooks = SessionHooks(
        onUserPromptSubmitted: (input, inv) async =>
            const UserPromptSubmittedOutput(),
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onSessionStart is set', () {
      final hooks = SessionHooks(
        onSessionStart: (input, inv) async => null,
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onSessionEnd is set', () {
      final hooks = SessionHooks(
        onSessionEnd: (input, inv) async => null,
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onErrorOccurred is set', () {
      final hooks = SessionHooks(
        onErrorOccurred: (input, inv) async => null,
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when all hooks are set', () {
      final hooks = SessionHooks(
        onPreToolUse: (i, inv) async => const PreToolUseOutput(),
        onPostToolUse: (i, inv) async => const PostToolUseOutput(),
        onUserPromptSubmitted: (i, inv) async =>
            const UserPromptSubmittedOutput(),
        onSessionStart: (i, inv) async => null,
        onSessionEnd: (i, inv) async => null,
        onErrorOccurred: (i, inv) async => null,
      );

      expect(hooks.hasHooks, isTrue);
    });
  });

  // ── invoke dispatch ───────────────────────────────────────────────────

  group('invoke dispatch', () {
    test('dispatches preToolUse hook', () async {
      PreToolUseInput? receivedInput;
      HookInvocation? receivedInv;

      final hooks = SessionHooks(
        onPreToolUse: (input, inv) async {
          receivedInput = input;
          receivedInv = inv;
          return PreToolUseOutput(
            permissionDecision: 'allow',
            permissionDecisionReason: 'Approved: ${input.toolName}',
          );
        },
      );

      final result = await hooks.invoke(
        'preToolUse',
        {
          'toolName': 'bash',
          'toolArgs': {'cmd': 'ls'},
          'timestamp': 1234567890,
          'cwd': '/tmp',
        },
        'session-1',
      );

      expect(receivedInput, isNotNull);
      expect(receivedInput!.toolName, 'bash');
      expect(receivedInput!.toolArgs, {'cmd': 'ls'});
      expect(receivedInput!.timestamp, 1234567890);
      expect(receivedInput!.cwd, '/tmp');

      expect(receivedInv, isNotNull);
      expect(receivedInv!.sessionId, 'session-1');

      expect(result, isA<PreToolUseOutput>());
      final output = result as PreToolUseOutput;
      expect(output.permissionDecision, 'allow');
      expect(output.permissionDecisionReason, 'Approved: bash');
    });

    test('dispatches postToolUse hook', () async {
      PostToolUseInput? receivedInput;

      final hooks = SessionHooks(
        onPostToolUse: (input, inv) async {
          receivedInput = input;
          return PostToolUseOutput(modifiedResult: 'modified result');
        },
      );

      final result = await hooks.invoke(
        'postToolUse',
        {
          'toolName': 'bash',
          'toolArgs': {'cmd': 'ls'},
          'toolResult': 'original',
          'timestamp': 100,
          'cwd': '/home',
        },
        'session-1',
      );

      expect(receivedInput!.toolName, 'bash');
      expect(receivedInput!.toolArgs, {'cmd': 'ls'});
      expect(receivedInput!.toolResult, 'original');

      expect(result, isA<PostToolUseOutput>());
      expect((result as PostToolUseOutput).modifiedResult, 'modified result');
    });

    test('dispatches userPromptSubmitted hook', () async {
      UserPromptSubmittedInput? receivedInput;

      final hooks = SessionHooks(
        onUserPromptSubmitted: (input, inv) async {
          receivedInput = input;
          return UserPromptSubmittedOutput(
            modifiedPrompt: 'Modified: ${input.prompt}',
          );
        },
      );

      final result = await hooks.invoke(
        'userPromptSubmitted',
        {'prompt': 'Hello Copilot', 'timestamp': 100, 'cwd': '/home'},
        'session-1',
      );

      expect(receivedInput!.prompt, 'Hello Copilot');

      expect(result, isA<UserPromptSubmittedOutput>());
      expect(
        (result as UserPromptSubmittedOutput).modifiedPrompt,
        'Modified: Hello Copilot',
      );
    });

    test('dispatches sessionStart hook', () async {
      SessionStartInput? receivedInput;

      final hooks = SessionHooks(
        onSessionStart: (input, inv) async {
          receivedInput = input;
          return null;
        },
      );

      final result = await hooks.invoke(
        'sessionStart',
        {'source': 'new', 'timestamp': 100, 'cwd': '/tmp'},
        'session-42',
      );

      expect(receivedInput!.source, 'new');
      expect(result, isNull);
    });

    test('dispatches sessionEnd hook', () async {
      SessionEndInput? receivedInput;

      final hooks = SessionHooks(
        onSessionEnd: (input, inv) async {
          receivedInput = input;
          return null;
        },
      );

      final result = await hooks.invoke(
        'sessionEnd',
        {
          'reason': 'complete',
          'finalMessage': 'Task completed',
          'timestamp': 100,
          'cwd': '/tmp',
        },
        'session-42',
      );

      expect(receivedInput!.reason, 'complete');
      expect(receivedInput!.finalMessage, 'Task completed');
      expect(result, isNull);
    });

    test('dispatches errorOccurred hook', () async {
      ErrorOccurredInput? receivedInput;

      final hooks = SessionHooks(
        onErrorOccurred: (input, inv) async {
          receivedInput = input;
          return null;
        },
      );

      final result = await hooks.invoke(
        'errorOccurred',
        {
          'error': 'Something failed',
          'errorContext': 'tool_execution',
          'recoverable': true,
          'timestamp': 100,
          'cwd': '/tmp',
        },
        'session-1',
      );

      expect(receivedInput!.error, 'Something failed');
      expect(receivedInput!.errorContext, 'tool_execution');
      expect(receivedInput!.recoverable, isTrue);
      expect(result, isNull);
    });

    test('returns null for unknown hook type', () async {
      final hooks = SessionHooks(
        onPreToolUse: (i, inv) async => const PreToolUseOutput(),
      );

      final result = await hooks.invoke(
        'unknownHookType',
        {'some': 'data'},
        'session-1',
      );

      expect(result, isNull);
    });

    test('returns null when matching hook is not set', () async {
      const hooks = SessionHooks();

      final result = await hooks.invoke(
        'preToolUse',
        {'toolName': 'test', 'timestamp': 0, 'cwd': ''},
        'session-1',
      );

      expect(result, isNull);
    });
  });

  // ── Input/Output Serialization ────────────────────────────────────────

  group('PreToolUseInput', () {
    test('fromJson with all fields', () {
      final input = PreToolUseInput.fromJson({
        'toolName': 'bash',
        'toolArgs': {'cmd': 'ls -la'},
        'timestamp': 1234567890,
        'cwd': '/workspace',
      });

      expect(input.toolName, 'bash');
      expect(input.toolArgs, {'cmd': 'ls -la'});
      expect(input.timestamp, 1234567890);
      expect(input.cwd, '/workspace');
    });

    test('fromJson with minimal fields', () {
      final input = PreToolUseInput.fromJson({
        'toolName': 'test',
      });

      expect(input.toolName, 'test');
      expect(input.toolArgs, isNull);
      expect(input.timestamp, 0);
      expect(input.cwd, '');
    });

    test('fromJson falls back from arguments to toolArgs', () {
      final input = PreToolUseInput.fromJson({
        'toolName': 'test',
        'arguments': {'a': 1},
      });

      expect(input.toolArgs, {'a': 1});
    });
  });

  group('PreToolUseOutput', () {
    test('toJson with all fields', () {
      const output = PreToolUseOutput(
        permissionDecision: 'deny',
        permissionDecisionReason: 'Not allowed',
        modifiedArgs: {'safe': true},
        additionalContext: 'extra info',
        suppressOutput: true,
      );

      final json = output.toJson();

      expect(json['permissionDecision'], 'deny');
      expect(json['permissionDecisionReason'], 'Not allowed');
      expect(json['modifiedArgs'], {'safe': true});
      expect(json['additionalContext'], 'extra info');
      expect(json['suppressOutput'], true);
    });

    test('toJson with no fields returns empty map', () {
      const output = PreToolUseOutput();
      final json = output.toJson();

      expect(json, isEmpty);
    });
  });

  group('PostToolUseInput', () {
    test('fromJson parses correctly', () {
      final input = PostToolUseInput.fromJson({
        'toolName': 'read_file',
        'toolArgs': {'path': '/tmp/f'},
        'toolResult': 'file content here',
        'timestamp': 999,
        'cwd': '/workspace',
      });

      expect(input.toolName, 'read_file');
      expect(input.toolArgs, {'path': '/tmp/f'});
      expect(input.toolResult, 'file content here');
    });

    test('fromJson falls back from result to toolResult', () {
      final input = PostToolUseInput.fromJson({
        'toolName': 'read_file',
        'result': 'fallback result',
      });

      expect(input.toolResult, 'fallback result');
    });
  });

  group('PostToolUseOutput', () {
    test('toJson includes modifiedResult and extras', () {
      const output = PostToolUseOutput(
        modifiedResult: 'modified',
        additionalContext: 'ctx',
        suppressOutput: false,
      );

      expect(output.toJson(), {
        'modifiedResult': 'modified',
        'additionalContext': 'ctx',
        'suppressOutput': false,
      });
    });

    test('toJson empty when no result', () {
      const output = PostToolUseOutput();

      expect(output.toJson(), isEmpty);
    });
  });

  group('UserPromptSubmittedInput', () {
    test('fromJson parses prompt with base fields', () {
      final input = UserPromptSubmittedInput.fromJson({
        'prompt': 'Write a test',
        'timestamp': 42,
        'cwd': '/home',
      });

      expect(input.prompt, 'Write a test');
      expect(input.timestamp, 42);
      expect(input.cwd, '/home');
    });
  });

  group('UserPromptSubmittedOutput', () {
    test('toJson with modifiedPrompt and extras', () {
      const output = UserPromptSubmittedOutput(
        modifiedPrompt: 'Modified prompt',
        additionalContext: 'additional',
        suppressOutput: true,
      );

      expect(output.toJson(), {
        'modifiedPrompt': 'Modified prompt',
        'additionalContext': 'additional',
        'suppressOutput': true,
      });
    });

    test('toJson empty when no update', () {
      const output = UserPromptSubmittedOutput();

      expect(output.toJson(), isEmpty);
    });
  });

  group('SessionStartInput', () {
    test('fromJson parses upstream fields', () {
      final input = SessionStartInput.fromJson({
        'source': 'resume',
        'initialPrompt': 'Hello',
        'timestamp': 100,
        'cwd': '/tmp',
      });

      expect(input.source, 'resume');
      expect(input.initialPrompt, 'Hello');
      expect(input.timestamp, 100);
      expect(input.cwd, '/tmp');
    });

    test('fromJson with minimal fields uses defaults', () {
      final input = SessionStartInput.fromJson({});

      expect(input.source, 'new');
      expect(input.initialPrompt, isNull);
    });
  });

  group('SessionStartOutput', () {
    test('toJson with all fields', () {
      const output = SessionStartOutput(
        additionalContext: 'ctx',
        modifiedConfig: {'key': 'value'},
      );

      expect(output.toJson(), {
        'additionalContext': 'ctx',
        'modifiedConfig': {'key': 'value'},
      });
    });

    test('toJson empty when no fields', () {
      const output = SessionStartOutput();
      expect(output.toJson(), isEmpty);
    });
  });

  group('SessionEndInput', () {
    test('fromJson with all fields', () {
      final input = SessionEndInput.fromJson({
        'reason': 'error',
        'finalMessage': 'Done',
        'error': 'something broke',
        'timestamp': 100,
        'cwd': '/tmp',
      });

      expect(input.reason, 'error');
      expect(input.finalMessage, 'Done');
      expect(input.error, 'something broke');
    });

    test('fromJson with minimal fields', () {
      final input = SessionEndInput.fromJson({});

      expect(input.reason, 'complete');
      expect(input.finalMessage, isNull);
      expect(input.error, isNull);
    });
  });

  group('SessionEndOutput', () {
    test('toJson with all fields', () {
      const output = SessionEndOutput(
        suppressOutput: true,
        cleanupActions: ['close-db', 'flush-logs'],
        sessionSummary: 'summary',
      );

      expect(output.toJson(), {
        'suppressOutput': true,
        'cleanupActions': ['close-db', 'flush-logs'],
        'sessionSummary': 'summary',
      });
    });

    test('toJson empty when no fields', () {
      const output = SessionEndOutput();
      expect(output.toJson(), isEmpty);
    });
  });

  group('ErrorOccurredInput', () {
    test('fromJson with all fields', () {
      final input = ErrorOccurredInput.fromJson({
        'error': 'null is not an object',
        'errorContext': 'model_call',
        'recoverable': true,
        'timestamp': 100,
        'cwd': '/tmp',
      });

      expect(input.error, 'null is not an object');
      expect(input.errorContext, 'model_call');
      expect(input.recoverable, isTrue);
    });

    test('fromJson falls back from errorType/message to error/errorContext',
        () {
      final input = ErrorOccurredInput.fromJson({
        'errorType': 'TypeError',
        'message': 'oops',
      });

      expect(input.error, 'oops');
      expect(input.errorContext, 'TypeError');
      expect(input.recoverable, isFalse);
    });
  });

  group('ErrorOccurredOutput', () {
    test('toJson with all fields', () {
      const output = ErrorOccurredOutput(
        suppressOutput: true,
        errorHandling: 'retry',
        retryCount: 3,
        userNotification: 'Retrying...',
      );

      expect(output.toJson(), {
        'suppressOutput': true,
        'errorHandling': 'retry',
        'retryCount': 3,
        'userNotification': 'Retrying...',
      });
    });

    test('toJson empty when no fields', () {
      const output = ErrorOccurredOutput();
      expect(output.toJson(), isEmpty);
    });
  });

  // ── HookInvocation ────────────────────────────────────────────────────

  group('HookInvocation', () {
    test('stores sessionId', () {
      const inv = HookInvocation(sessionId: 'session-99');

      expect(inv.sessionId, 'session-99');
    });
  });
}
