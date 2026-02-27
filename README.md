# Copilot SDK for Dart

A community-maintained Dart SDK for the [GitHub Copilot CLI SDK](https://github.com/github/copilot-sdk). Enables programmatic access to Copilot agent capabilities via JSON-RPC 2.0 over stdio, TCP, or WebSocket.

> This is an unofficial project and is not affiliated with, endorsed by, or sponsored by GitHub, Inc. or Microsoft Corporation.

[![Dart](https://github.com/owlxcorp/copilot_sdk_dart/actions/workflows/ci.yml/badge.svg)](https://github.com/owlxcorp/copilot_sdk_dart/actions/workflows/ci.yml)

## Features

- **Full protocol support** — All JSON-RPC 2.0 methods from the Copilot CLI (protocol v2)
- **Session management** — Create, resume, list, and destroy sessions
- **Event streaming** — 25+ typed event classes with Dart 3 exhaustive pattern matching
- **Custom tools** — Register and handle custom tools with typed results
- **Hooks** — 6 lifecycle hooks (preToolUse, postToolUse, userPromptSubmitted, sessionStart, sessionEnd, errorOccurred)
- **Permission & user input handlers** — Approve/deny tool permissions, handle user input requests
- **Pluggable transports** — stdio (desktop), TCP (desktop), WebSocket (web via bridge)
- **Idiomatic Dart** — Sealed classes, Streams, Futures, strong typing throughout

## Prerequisites

- Dart SDK `^3.6.0`
- [Copilot CLI](https://docs.github.com/en/copilot/using-github-copilot/using-github-copilot-in-the-command-line) installed
- Authenticated: `copilot auth login`

## Quick Start

```dart
import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

Future<void> main() async {
  // Create transport & client
  final transport = StdioTransport(
    executable: 'copilot',
    arguments: ['--acp', '--no-auto-update'],
  );
  await transport.start();

  final client = CopilotClient(
    options: const CopilotClientOptions(),
    transport: transport,
  );
  await client.start();

  // Create a session
  final session = await client.createSession(
    config: SessionConfig(
      onPermissionRequest: approveAllPermissions,
    ),
  );

  // Listen for events with exhaustive pattern matching
  session.on((event) {
    switch (event) {
      case AssistantMessageEvent(:final content):
        print(content);
      case SessionIdleEvent():
        print('--- Done ---');
      default:
        break;
    }
  });

  // Send a message and wait for the reply
  final reply = await session.sendAndWait('What is 2 + 2?');
  print('Reply: ${reply?.content}');

  // Cleanup
  await session.destroy();
  await client.stop();
}
```

## Interactive Example App

For a full app-style sample (interactive chat + one-shot smoke mode), run:

```bash
# Interactive REPL chat
dart run example/chat_app.dart

# One-shot prompt (good for smoke testing)
dart run example/chat_app.dart --prompt "Explain JSON-RPC in one sentence."

# Optional model override
dart run example/chat_app.dart --model claude-sonnet-4.5

# Override CLI executable/args (for custom SDK server runtime)
dart run example/chat_app.dart --cli-path /path/to/copilot --cli-arg --acp --cli-arg --no-auto-update
```

The app validates auth status, creates a session, handles events, sends prompts,
prints assistant replies, and performs graceful cleanup.

If startup times out on `ping`, your executable likely is not exposing the
Copilot SDK JSON-RPC server methods (`ping`, `session.create`, etc.). Provide a
compatible runtime via `--cli-path` / `--cli-arg`.
You can also set `COPILOT_CLI_PATH` to point to a compatible runtime.
When using the launcher CLI, include `--no-auto-update` to avoid silent runtime version drift.

## Architecture

```
┌─────────────────────┐       JSON-RPC 2.0        ┌──────────────┐
│   CopilotClient     │ ◄─── Content-Length ────► │ Copilot CLI  │
│   CopilotSession    │       framed stdio/TCP    │ (--acp)      │
│   Event handlers    │                           │              │
│   Tool handlers     │  Client → Server:         │  LLM proxy   │
│   Permission/Input  │   ping, session.create,   │  with tools  │
│   Hooks             │   session.send, ...       │              │
│                     │                           │              │
│                     │  Server → Client:         │              │
│                     │   session.event,           │              │
│                     │   toolCall.request, ...    │              │
└─────────────────────┘                           └──────────────┘
```

### Transport Layer

| Transport | Platform | Use Case |
|-----------|----------|----------|
| `StdioTransport` | Desktop/Server | Spawns `copilot --acp` process |
| `TcpTransport` | Desktop/Server | Connects to running CLI server |
| `WebSocketTransport` | Web | Connects to WebSocket bridge server |

### Imports

```dart
// Transport-agnostic (types, client, session)
import 'package:copilot_sdk_dart/copilot_sdk.dart';

// Desktop/Server (includes stdio & TCP transports)
import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

// Web (includes WebSocket transport)
import 'package:copilot_sdk_dart/copilot_sdk_web.dart';
```

## Custom Tools

```dart
final tool = Tool(
  name: 'get_weather',
  description: 'Get weather for a city',
  parameters: {
    'type': 'object',
    'properties': {
      'city': {'type': 'string', 'description': 'City name'},
    },
    'required': ['city'],
  },
  handler: (args, invocation) async {
    final city = (args as Map<String, dynamic>)['city'] as String;
    return ToolResult.success('Weather in $city: Sunny, 72°F');
  },
);

final session = await client.createSession(
  config: SessionConfig(
    tools: [tool],
    onPermissionRequest: approveAllPermissions,
  ),
);
```

## Event Types

All 46 event types are modeled as Dart 3 sealed classes for exhaustive pattern matching:

| Category | Events |
|----------|--------|
| Session lifecycle | `SessionStartEvent`, `SessionResumeEvent`, `SessionIdleEvent`, `SessionShutdownEvent`, `SessionErrorEvent`, `SessionInfoEvent`, `SessionWarningEvent`, `SessionTaskCompleteEvent` |
| Session state | `SessionTitleChangedEvent`, `SessionModelChangeEvent`, `SessionModeChangedEvent`, `SessionPlanChangedEvent`, `SessionTruncationEvent`, `SessionContextChangedEvent`, `SessionUsageInfoEvent`, `SessionSnapshotRewindEvent`, `SessionHandoffEvent`, `SessionWorkspaceFileChangedEvent`, `SessionCompactionStartEvent`, `SessionCompactionCompleteEvent` |
| Messages | `AssistantMessageEvent`, `AssistantMessageDeltaEvent`, `AssistantStreamingDeltaEvent`, `AssistantReasoningEvent`, `AssistantReasoningDeltaEvent`, `AssistantIntentEvent`, `AssistantUsageEvent`, `AssistantTurnStartEvent`, `AssistantTurnEndEvent`, `UserMessageEvent`, `PendingMessagesModifiedEvent`, `SystemMessageEvent`, `AbortEvent` |
| Tools | `ToolUserRequestedEvent`, `ToolExecutionStartEvent`, `ToolExecutionPartialResultEvent`, `ToolExecutionProgressEvent`, `ToolExecutionCompleteEvent` |
| Skills & agents | `SkillInvokedEvent`, `SubagentStartedEvent`, `SubagentCompletedEvent`, `SubagentFailedEvent`, `SubagentSelectedEvent` |
| Hooks | `HookStartEvent`, `HookEndEvent` |
| Fallback | `UnknownEvent` (for forward compatibility) |

## Session API

```dart
// Send message
await session.send('Hello');

// Send and wait for complete reply
final reply = await session.sendAndWait('Explain X', timeout: Duration(minutes: 2));

// Model management
final model = await session.getCurrentModel();
await session.switchModel('claude-sonnet-4.5');

// Mode management
await session.setMode(AgentMode.autopilot);

// Plan management
final plan = await session.readPlan();
await session.updatePlan('Updated plan content');

// Workspace
final files = await session.listWorkspaceFiles();
final content = await session.readWorkspaceFile('src/main.dart');

// Fleet mode (parallel sub-agents)
await session.startFleet();

// Lifecycle
await session.abort();
await session.destroy();
```

## Client API

```dart
// Server info
final status = await client.getStatus();
final auth = await client.getAuthStatus();

// Discovery
final models = await client.listModels();
final tools = await client.listTools();
final quota = await client.getAccountQuota();

// Session management
final sessions = await client.listSessions();
await client.deleteSession('session-id');
```

## Web Support

The Copilot CLI only supports stdio and TCP. For web, use a WebSocket bridge server:

```dart
import 'package:copilot_sdk_dart/copilot_sdk_web.dart';

final transport = WebSocketTransport(
  uri: Uri.parse('ws://localhost:8765'),
);
await transport.connect();

final client = CopilotClient(
  options: const CopilotClientOptions(),
  transport: transport,
);
```

The bridge server (not included) relays WebSocket ↔ CLI stdio. Any language can implement it.

## License

MIT — see [LICENSE](LICENSE).

## Legal and Trademark Notice

- The upstream [`github/copilot-sdk`](https://github.com/github/copilot-sdk) project is MIT licensed, which permits creating and publishing compatible ports.
- "GitHub" and "GitHub Copilot" are trademarks of GitHub, Inc.; "Microsoft" is a trademark of Microsoft Corporation.
- Trademarked names are used only to describe compatibility and do not imply affiliation or endorsement.
