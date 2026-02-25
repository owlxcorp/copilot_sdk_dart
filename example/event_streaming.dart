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
  final client = CopilotClient();
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
      case AssistantReasoningEvent(:final content):
        print(
            '[$ts] 🤔 Thinking: ${content.substring(0, content.length.clamp(0, 80))}...');
      case AssistantMessageEvent(:final content):
        stdout.write(content);
      case ToolUserRequestedEvent(:final toolName, :final toolCallId):
        print('[$ts] 🔧 Tool call requested: $toolName ($toolCallId)');
      case ToolExecutionStartEvent(:final toolName):
        print('[$ts] ⏳ Executing: $toolName');
      case ToolExecutionCompleteEvent(:final toolCallId, :final success):
        print('[$ts] ✅ Complete: $toolCallId (success: $success)');
      case SessionTitleChangedEvent(:final title):
        print('[$ts] 📝 Title: $title');
      case SessionModelChangeEvent(:final newModel):
        print('[$ts] 🔄 Model: $newModel');
      case SessionModeChangedEvent(:final previousMode, :final newMode):
        print('[$ts] 🎯 Mode: $previousMode -> $newMode');
      case SessionErrorEvent(:final message, :final statusCode):
        print('[$ts] ❌ Error (${statusCode ?? 'n/a'}): $message');
      case SessionIdleEvent():
        print('\n[$ts] 💤 Idle');
      case SessionShutdownEvent(:final shutdownType, :final errorReason):
        print(
            '[$ts] 🔴 Shutdown: $shutdownType (${errorReason ?? 'no error'})');
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
