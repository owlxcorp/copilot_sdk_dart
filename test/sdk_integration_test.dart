import 'dart:async';
import 'dart:io';
import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

int eventCount = 0;
int deltaCount = 0;
bool sessionDied = false;
DateTime? firstEvent;

void main() async {
  print('=== SDK Integration Test (using actual SDK classes) ===');

  final transport = StdioTransport(
    executable: '/opt/homebrew/bin/copilot',
    arguments: ['--headless', '--stdio', '--no-auto-update'],
  );

  final client = CopilotClient(
    options: CopilotClientOptions(
      useLoggedInUser: true,
      autoRestart: false,
      log: (msg) {
        if (!msg.contains('← notification')) {
          print('SDK: $msg');
        }
      },
    ),
    transport: transport,
  );

  client.onConnectionStateChanged = (state) {
    print('Connection: $state');
    if (state == ConnectionState.disconnected) {
      sessionDied = true;
      print('DISCONNECTED!');
      print('Total events: $eventCount, deltas: $deltaCount');
      print('Stderr: ${transport.stderrBuffer}');
      print('ExitCode: ${transport.lastExitCode}');
      print('PID: ${transport.pid}');
    }
  };

  client.onError = (error) {
    print('Client error: $error');
  };

  try {
    await client.start();
    print('Client started');
  } catch (e) {
    print('Failed to start: $e');
    exit(1);
  }

  // Build 30 tools (same count as Flutter app)
  final tools = List.generate(
      30,
      (i) => Tool(
            name: 'tool_$i',
            description: 'Test tool number $i',
            parameters: {
              'type': 'object',
              'properties': {
                'query': {'type': 'string', 'description': 'Query'},
              },
            },
            handler: (args, invocation) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return ToolResultSuccess('Tool $i result: ok');
            },
          ));

  CopilotSession session;
  try {
    session = await client.createSession(
      config: SessionConfig(
        tools: tools,
        streaming: true,
        infiniteSessions: InfiniteSessionConfig(enabled: true),
        onPermissionRequest: (request, invocation) async {
          return PermissionResult.approved;
        },
        systemMessage: SystemMessageAppend(
          content: 'You are a test assistant. Respond in detail.',
        ),
      ),
    );
    print('Session created: ${session.sessionId}');
  } catch (e) {
    print('Failed to create session: $e');
    await client.stop();
    exit(1);
  }

  final completer = Completer<void>();
  String content = '';

  session.events.listen(
    (event) {
      eventCount++;
      firstEvent ??= DateTime.now();

      if (event is AssistantMessageDeltaEvent) {
        deltaCount++;
        content += event.deltaContent;
        // Simulate some work per delta (like notifyListeners)
        for (var i = 0; i < 5; i++) {
          eventCount.hashCode;
        }
      } else {
        print('Event #$eventCount: ${event.type}');
      }

      if (eventCount % 100 == 0) {
        print('... $eventCount events ($deltaCount deltas)');
      }
    },
    onError: (Object error) => print('Event error: $error'),
    onDone: () {
      print('Event stream closed ($eventCount events, $deltaCount deltas)');
      if (!completer.isCompleted) completer.complete();
    },
  );

  // Send message
  print('\nSending: "explain quantum computing in detail"');
  try {
    await session
        .send('explain quantum computing in detail with many paragraphs');
  } catch (e) {
    print('Send failed: $e');
  }

  // Wait
  print('Waiting 120s...');
  await Future.any([
    completer.future,
    Future<void>.delayed(const Duration(seconds: 120)),
  ]);

  if (!sessionDied) {
    print('\n✅ SURVIVED: $eventCount events, $deltaCount deltas');
    print('Content: ${content.substring(0, content.length.clamp(0, 200))}...');

    // Second message
    print('\nSending second message...');
    final count1 = eventCount;
    try {
      await session.send('now explain relativity in detail');
      await Future<void>.delayed(const Duration(seconds: 30));
      print('✅ Second survived: ${eventCount - count1} more events');
    } catch (e) {
      print('Second failed: $e');
    }
  } else {
    print('\n❌ DIED: $eventCount events');
  }

  try {
    await client.stop();
  } catch (_) {}
  print('Done.');
  exit(sessionDied ? 1 : 0);
}
