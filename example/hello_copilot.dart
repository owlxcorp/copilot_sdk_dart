/// Minimal example: Create a client, session, and send a message.
///
/// Run with: dart run example/hello_copilot.dart
///
/// Prerequisites:
///   - Copilot CLI installed and in PATH (`copilot --version`)
///   - Authenticated (`copilot auth login`)
library;

import 'dart:io';

import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

Future<void> main() async {
  // 1. Create the client (automatically spawns CLI with required flags)
  final client = CopilotClient(
    options: const CopilotClientOptions(),
  );
  await client.start();

  // 2. Check auth
  final auth = await client.getAuthStatus();
  if (!auth.isAuthenticated) {
    print('Not authenticated. Run: copilot auth login');
    await client.stop();
    exit(1);
  }
  print('Authenticated as: ${auth.login}');

  // 3. Create a session
  final session = await client.createSession(
    config: SessionConfig(
      onPermissionRequest: approveAllPermissions,
    ),
  );

  // 4. Listen for events
  session.on((event) {
    switch (event) {
      case AssistantMessageEvent(:final content):
        stdout.write(content);
      case SessionIdleEvent():
        print('\n--- Turn complete ---');
      case SessionErrorEvent(:final message):
        stderr.writeln('Error: $message');
      default:
        break;
    }
  });

  // 5. Send a message and wait for reply
  final reply = await session.sendAndWait('What is 2 + 2?');
  print('\nReply: ${reply?.content}');

  // 6. Cleanup
  await session.destroy();
  await client.stop();
}
