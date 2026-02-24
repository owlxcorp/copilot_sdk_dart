/// Interactive example app for the Copilot SDK.
///
/// Supports:
/// - REPL mode: `dart run example/chat_app.dart`
/// - One-shot mode: `dart run example/chat_app.dart --prompt "Explain JSON-RPC"`
/// - Optional model: `dart run example/chat_app.dart --model claude-sonnet-4.5`
///
/// Prerequisites:
/// - Copilot CLI installed and in PATH (`copilot --version`)
/// - Authenticated (`copilot auth login`)
library;

import 'dart:async';
import 'dart:io';

import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

Future<void> main(List<String> args) async {
  _CliArgs parsed;
  try {
    parsed = _CliArgs.parse(args);
  } on FormatException catch (e) {
    stderr.writeln('Argument error: ${e.message}');
    _printUsage();
    exitCode = 64;
    return;
  }

  if (parsed.showHelp) {
    _printUsage();
    return;
  }

  CopilotClient? client;
  CopilotSession? session;

  try {
    client = await _startClientWithRetry(parsed);

    final auth = await client.getAuthStatus();
    if (!auth.isAuthenticated) {
      stderr.writeln('Copilot CLI is not authenticated.');
      stderr.writeln('Run: copilot auth login');
      exitCode = 1;
      return;
    }

    stdout.writeln('Authenticated as: ${auth.login ?? 'unknown user'}');
    session = await client.createSession(
      config: SessionConfig(
        model: parsed.model,
        onPermissionRequest: approveAllPermissions,
      ),
    );

    session.on((event) {
      switch (event) {
        case AssistantThinkingEvent(:final content):
          if (content.trim().isNotEmpty) {
            stdout.writeln('[reasoning] $content');
          }
        case ToolExecutionStartEvent(:final toolName):
          stdout.writeln('[tool:start] $toolName');
        case ToolExecutionCompleteEvent(:final toolName):
          stdout.writeln('[tool:done] $toolName');
        case SessionErrorEvent(:final error):
          stderr.writeln('[session:error] $error');
        default:
          break;
      }
    });

    if (parsed.prompt != null) {
      final ok = await _sendPrompt(session, parsed.prompt!);
      if (!ok) exitCode = 1;
      return;
    }

    await _runRepl(session);
  } on ProcessException catch (e) {
    stderr.writeln('Failed to start Copilot CLI: ${e.message}');
    stderr.writeln('Ensure `copilot` is installed and in PATH.');
    exitCode = 1;
  } on StateError catch (e) {
    stderr.writeln(e.message);
    stderr.writeln(
      'Tip: ensure the executable exposes the Copilot SDK JSON-RPC server '
      '(ping/session.create methods).',
    );
    stderr.writeln(
      'You can override executable/args via --cli-path and --cli-arg.',
    );
    exitCode = 1;
  } catch (e) {
    stderr.writeln('Unexpected error: $e');
    exitCode = 1;
  } finally {
    try {
      await session?.destroy();
    } catch (_) {}
    try {
      await client?.stop();
    } catch (_) {}
  }
}

Future<CopilotClient> _startClientWithRetry(_CliArgs args) async {
  Object? lastError;
  for (var attempt = 1; attempt <= 3; attempt++) {
    final cliArgs = args.cliArgs.isEmpty
        ? const ['--headless', '--stdio', '--no-auto-update']
        : args.cliArgs;
    final transport = StdioTransport(
      executable: args.cliPath,
      arguments: cliArgs,
    );
    final candidate = CopilotClient(
      options: const CopilotClientOptions(),
      transport: transport,
    );

    try {
      await transport.start();
      await candidate.start();
      return candidate;
    } on TimeoutException catch (e) {
      lastError = e;
      await _safeStop(candidate);
      if (attempt == 3) break;
      stderr.writeln(
        'Copilot CLI startup timed out (attempt $attempt/3); retrying...',
      );
      await Future<void>.delayed(Duration(seconds: attempt * 2));
    } catch (e) {
      await _safeStop(candidate);
      rethrow;
    }
  }

  throw StateError(
    'Failed to start Copilot client after retries. '
    'Last error: $lastError',
  );
}

Future<void> _safeStop(CopilotClient client) async {
  try {
    await client.stop();
  } catch (_) {}
}

Future<void> _runRepl(CopilotSession session) async {
  stdout.writeln('Chat with Copilot (type /quit to exit)');
  while (true) {
    stdout.write('\nYou: ');
    final input = stdin.readLineSync();
    if (input == null) {
      stdout.writeln('\nEOF received, exiting.');
      return;
    }

    final prompt = input.trim();
    if (prompt.isEmpty) continue;
    if (prompt == '/quit' || prompt == '/exit') return;

    final ok = await _sendPrompt(session, prompt);
    if (!ok) {
      stderr.writeln('Prompt failed; you can retry or type /quit to exit.');
    }
  }
}

Future<bool> _sendPrompt(CopilotSession session, String prompt) async {
  stdout.writeln('\nAssistant:');
  final reply = await session.sendAndWait(
    prompt,
    timeout: const Duration(minutes: 2),
  );
  if (reply == null) {
    stderr.writeln('No assistant reply before timeout.');
    return false;
  }
  stdout.writeln(reply.content);
  return true;
}

void _printUsage() {
  stdout.writeln('Copilot SDK Dart chat example');
  stdout.writeln('');
  stdout.writeln('Usage:');
  stdout.writeln('  dart run example/chat_app.dart');
  stdout.writeln(
      '  dart run example/chat_app.dart --prompt "Explain JSON-RPC in one sentence."');
  stdout.writeln('  dart run example/chat_app.dart --model <model-id>');
  stdout.writeln('  dart run example/chat_app.dart --cli-path <path>');
  stdout.writeln('  dart run example/chat_app.dart --cli-arg <arg>');
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --prompt <text>   Run one prompt then exit');
  stdout.writeln('  --model <id>      Use a specific model for the session');
  stdout.writeln(
      '  --cli-path <path> CLI executable path (default: COPILOT_CLI_PATH or copilot)');
  stdout.writeln(
      '  --cli-arg <arg>   Repeatable CLI arg; defaults to --headless --stdio --no-auto-update');
  stdout.writeln('  -h, --help        Show this help');
}

class _CliArgs {
  _CliArgs({
    required this.prompt,
    required this.model,
    required this.cliPath,
    required this.cliArgs,
    required this.showHelp,
  });

  final String? prompt;
  final String? model;
  final String cliPath;
  final List<String> cliArgs;
  final bool showHelp;

  static _CliArgs parse(List<String> args) {
    String? prompt;
    String? model;
    var cliPath = Platform.environment['COPILOT_CLI_PATH'] ?? 'copilot';
    final cliArgs = <String>[];
    var showHelp = false;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      switch (arg) {
        case '--prompt':
          if (i + 1 >= args.length) {
            throw const FormatException('--prompt requires a value');
          }
          prompt = args[++i];
        case '--model':
          if (i + 1 >= args.length) {
            throw const FormatException('--model requires a value');
          }
          model = args[++i];
        case '--cli-path':
          if (i + 1 >= args.length) {
            throw const FormatException('--cli-path requires a value');
          }
          cliPath = args[++i];
        case '--cli-arg':
          if (i + 1 >= args.length) {
            throw const FormatException('--cli-arg requires a value');
          }
          cliArgs.add(args[++i]);
        case '-h':
        case '--help':
          showHelp = true;
        default:
          throw FormatException('Unknown argument: $arg');
      }
    }

    return _CliArgs(
      prompt: prompt,
      model: model,
      cliPath: cliPath,
      cliArgs: cliArgs,
      showHelp: showHelp,
    );
  }
}
