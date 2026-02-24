/// Example: Stream and display events in real-time.
///
/// Demonstrates using the Dart Stream API for event handling.
///
/// Run with: dart run example/event_streaming.dart
library;

import 'dart:async';
import 'dart:io';

import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

Future<void> main() async {
  final transport = StdioTransport(
    executable: 'copilot',
    arguments: ['--headless', '--stdio', '--no-auto-update'],
  );
  await transport.start();

  final client = CopilotClient(
    options: const CopilotClientOptions(),
    transport: transport,
  );
  await client.start();

  final session = await client.createSession(
    config: SessionConfig(
      onPermissionRequest: approveAllPermissions,
    ),
  );

  // Use Dart Stream API for event handling
  final subscription = session.events.listen((event) {
    final ts = event.timestamp;
    switch (event) {
      case SessionStartEvent(:final sessionId):
        print('[$ts] 🟢 Session started: $sessionId');
      case AssistantThinkingEvent(:final content):
        print(
            '[$ts] 🤔 Thinking: ${content.substring(0, content.length.clamp(0, 80))}...');
      case AssistantMessageEvent(:final content):
        stdout.write(content);
      case ToolCallEvent(:final toolName, :final toolCallId):
        print('[$ts] 🔧 Tool call: $toolName ($toolCallId)');
      case ToolExecutionStartEvent(:final toolName):
        print('[$ts] ⏳ Executing: $toolName');
      case ToolExecutionCompleteEvent(:final toolName):
        print('[$ts] ✅ Complete: $toolName');
      case SessionTitleChangedEvent(:final title):
        print('[$ts] 📝 Title: $title');
      case SessionModelChangeEvent(:final modelId):
        print('[$ts] 🔄 Model: $modelId');
      case SessionModeChangedEvent(:final mode):
        print('[$ts] 🎯 Mode: $mode');
      case SessionErrorEvent(:final error, :final code):
        print('[$ts] ❌ Error ($code): $error');
      case SessionIdleEvent():
        print('\n[$ts] 💤 Idle');
      case SessionShutdownEvent(:final reason):
        print('[$ts] 🔴 Shutdown: $reason');
      default:
        print('[$ts] ℹ️ ${event.type}');
    }
  });

  // Send a message
  await session.send('Explain the Fibonacci sequence in 3 sentences.');

  // Wait for idle
  await session.events
      .firstWhere((e) => e is SessionIdleEvent)
      .timeout(const Duration(minutes: 2));

  await subscription.cancel();
  await session.destroy();
  await client.stop();
}
