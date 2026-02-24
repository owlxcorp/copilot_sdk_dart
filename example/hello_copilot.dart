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
  // 1. Create a stdio transport that spawns the CLI
  final transport = StdioTransport(
    executable: 'copilot',
    arguments: ['--headless', '--stdio', '--no-auto-update'],
  );
  await transport.start();

  // 2. Create the client
  final client = CopilotClient(
    options: const CopilotClientOptions(),
    transport: transport,
  );
  await client.start();

  // 3. Check auth
  final auth = await client.getAuthStatus();
  if (!auth.isAuthenticated) {
    print('Not authenticated. Run: copilot auth login');
    await client.stop();
    exit(1);
  }
  print('Authenticated as: ${auth.login}');

  // 4. Create a session
  final session = await client.createSession(
    config: SessionConfig(
      onPermissionRequest: approveAllPermissions,
    ),
  );

  // 5. Listen for events
  session.on((event) {
    switch (event) {
      case AssistantMessageEvent(:final content):
        stdout.write(content);
      case SessionIdleEvent():
        print('\n--- Turn complete ---');
      case SessionErrorEvent(:final error):
        stderr.writeln('Error: $error');
      default:
        break;
    }
  });

  // 6. Send a message and wait for reply
  final reply = await session.sendAndWait('What is 2 + 2?');
  print('\nReply: ${reply?.content}');

  // 7. Cleanup
  await session.destroy();
  await client.stop();
}
