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
        onSessionStart: (input, inv) async {},
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onSessionEnd is set', () {
      final hooks = SessionHooks(
        onSessionEnd: (input, inv) async {},
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when onErrorOccurred is set', () {
      final hooks = SessionHooks(
        onErrorOccurred: (input, inv) async {},
      );

      expect(hooks.hasHooks, isTrue);
    });

    test('returns true when all hooks are set', () {
      final hooks = SessionHooks(
        onPreToolUse: (i, inv) async => const PreToolUseOutput(),
        onPostToolUse: (i, inv) async => const PostToolUseOutput(),
        onUserPromptSubmitted: (i, inv) async =>
            const UserPromptSubmittedOutput(),
        onSessionStart: (i, inv) async {},
        onSessionEnd: (i, inv) async {},
        onErrorOccurred: (i, inv) async {},
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
            decision: 'approve',
            message: 'Approved: ${input.toolName}',
          );
        },
      );

      final result = await hooks.invoke(
        'preToolUse',
        {
          'toolName': 'bash',
          'toolCallId': 'tc-1',
          'arguments': {'cmd': 'ls'}
        },
        'session-1',
      );

      expect(receivedInput, isNotNull);
      expect(receivedInput!.toolName, 'bash');
      expect(receivedInput!.toolCallId, 'tc-1');
      expect(receivedInput!.arguments, {'cmd': 'ls'});

      expect(receivedInv, isNotNull);
      expect(receivedInv!.sessionId, 'session-1');

      expect(result, isA<PreToolUseOutput>());
      final output = result as PreToolUseOutput;
      expect(output.decision, 'approve');
      expect(output.message, 'Approved: bash');
    });

    test('dispatches postToolUse hook', () async {
      PostToolUseInput? receivedInput;

      final hooks = SessionHooks(
        onPostToolUse: (input, inv) async {
          receivedInput = input;
          return PostToolUseOutput(updatedResult: 'modified result');
        },
      );

      final result = await hooks.invoke(
        'postToolUse',
        {'toolName': 'bash', 'toolCallId': 'tc-2', 'result': 'original'},
        'session-1',
      );

      expect(receivedInput!.toolName, 'bash');
      expect(receivedInput!.toolCallId, 'tc-2');
      expect(receivedInput!.result, 'original');

      expect(result, isA<PostToolUseOutput>());
      expect((result as PostToolUseOutput).updatedResult, 'modified result');
    });

    test('dispatches userPromptSubmitted hook', () async {
      UserPromptSubmittedInput? receivedInput;

      final hooks = SessionHooks(
        onUserPromptSubmitted: (input, inv) async {
          receivedInput = input;
          return UserPromptSubmittedOutput(
            updatedPrompt: 'Modified: ${input.prompt}',
          );
        },
      );

      final result = await hooks.invoke(
        'userPromptSubmitted',
        {'prompt': 'Hello Copilot'},
        'session-1',
      );

      expect(receivedInput!.prompt, 'Hello Copilot');

      expect(result, isA<UserPromptSubmittedOutput>());
      expect(
        (result as UserPromptSubmittedOutput).updatedPrompt,
        'Modified: Hello Copilot',
      );
    });

    test('dispatches sessionStart hook', () async {
      SessionStartInput? receivedInput;

      final hooks = SessionHooks(
        onSessionStart: (input, inv) async {
          receivedInput = input;
        },
      );

      final result = await hooks.invoke(
        'sessionStart',
        {'sessionId': 'session-42'},
        'session-42',
      );

      expect(receivedInput!.sessionId, 'session-42');
      expect(result, isNull);
    });

    test('dispatches sessionEnd hook', () async {
      SessionEndInput? receivedInput;

      final hooks = SessionHooks(
        onSessionEnd: (input, inv) async {
          receivedInput = input;
        },
      );

      final result = await hooks.invoke(
        'sessionEnd',
        {'sessionId': 'session-42', 'summary': 'Task completed'},
        'session-42',
      );

      expect(receivedInput!.sessionId, 'session-42');
      expect(receivedInput!.summary, 'Task completed');
      expect(result, isNull);
    });

    test('dispatches errorOccurred hook', () async {
      ErrorOccurredInput? receivedInput;

      final hooks = SessionHooks(
        onErrorOccurred: (input, inv) async {
          receivedInput = input;
        },
      );

      final result = await hooks.invoke(
        'errorOccurred',
        {
          'errorType': 'RuntimeError',
          'message': 'Something failed',
          'stack': 'at line 42',
        },
        'session-1',
      );

      expect(receivedInput!.errorType, 'RuntimeError');
      expect(receivedInput!.message, 'Something failed');
      expect(receivedInput!.stack, 'at line 42');
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
        {'toolName': 'test'},
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
        'toolCallId': 'tc-1',
        'arguments': {'cmd': 'ls -la'},
      });

      expect(input.toolName, 'bash');
      expect(input.toolCallId, 'tc-1');
      expect(input.arguments, {'cmd': 'ls -la'});
    });

    test('fromJson with minimal fields', () {
      final input = PreToolUseInput.fromJson({
        'toolName': 'test',
      });

      expect(input.toolName, 'test');
      expect(input.toolCallId, isNull);
      expect(input.arguments, isNull);
    });
  });

  group('PreToolUseOutput', () {
    test('toJson with all fields', () {
      const output = PreToolUseOutput(
        decision: 'reject',
        message: 'Not allowed',
        updatedArguments: {'safe': true},
      );

      final json = output.toJson();

      expect(json['decision'], 'reject');
      expect(json['message'], 'Not allowed');
      expect(json['updatedArguments'], {'safe': true});
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
        'toolCallId': 'tc-5',
        'result': 'file content here',
      });

      expect(input.toolName, 'read_file');
      expect(input.toolCallId, 'tc-5');
      expect(input.result, 'file content here');
    });
  });

  group('PostToolUseOutput', () {
    test('toJson includes updatedResult', () {
      const output = PostToolUseOutput(updatedResult: 'modified');

      expect(output.toJson(), {'updatedResult': 'modified'});
    });

    test('toJson empty when no result', () {
      const output = PostToolUseOutput();

      expect(output.toJson(), isEmpty);
    });
  });

  group('UserPromptSubmittedInput', () {
    test('fromJson parses prompt', () {
      final input = UserPromptSubmittedInput.fromJson({
        'prompt': 'Write a test',
      });

      expect(input.prompt, 'Write a test');
    });
  });

  group('UserPromptSubmittedOutput', () {
    test('toJson with updatedPrompt', () {
      const output = UserPromptSubmittedOutput(
        updatedPrompt: 'Modified prompt',
      );

      expect(output.toJson(), {'updatedPrompt': 'Modified prompt'});
    });

    test('toJson empty when no update', () {
      const output = UserPromptSubmittedOutput();

      expect(output.toJson(), isEmpty);
    });
  });

  group('SessionStartInput', () {
    test('fromJson parses sessionId', () {
      final input = SessionStartInput.fromJson({'sessionId': 's-1'});

      expect(input.sessionId, 's-1');
    });
  });

  group('SessionEndInput', () {
    test('fromJson with summary', () {
      final input = SessionEndInput.fromJson({
        'sessionId': 's-1',
        'summary': 'Done',
      });

      expect(input.sessionId, 's-1');
      expect(input.summary, 'Done');
    });

    test('fromJson without summary', () {
      final input = SessionEndInput.fromJson({
        'sessionId': 's-1',
      });

      expect(input.summary, isNull);
    });
  });

  group('ErrorOccurredInput', () {
    test('fromJson with all fields', () {
      final input = ErrorOccurredInput.fromJson({
        'errorType': 'TypeError',
        'message': 'null is not an object',
        'stack': 'at main.dart:42',
      });

      expect(input.errorType, 'TypeError');
      expect(input.message, 'null is not an object');
      expect(input.stack, 'at main.dart:42');
    });

    test('fromJson without stack', () {
      final input = ErrorOccurredInput.fromJson({
        'errorType': 'Error',
        'message': 'oops',
      });

      expect(input.stack, isNull);
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
