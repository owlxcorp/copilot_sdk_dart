## 0.1.2

- Renamed main library file from `copilot_sdk.dart` to `copilot_sdk_dart.dart`
  to follow Dart package layout conventions (main library matches package name).
- Added missing dartdoc for `TcpTransport` constructor, `host`, `port`,
  `connectionTimeout`, and `AbortEvent`.

## 0.1.1

- **Fix: ContentLengthCodec false positive header size check**
  - The header size guard checked total buffer length before extracting the header
    separator. During streaming responses with large stdout chunks (header + body >
    16KB), the guard fired falsely, throwing `FormatException` and closing the
    session stream. Now only enforces the limit on actual header bytes (before
    `\r\n\r\n` separator).
- **Fix: Wire `JsonRpcConnection.onError` in CopilotClient**
  - Decoder and transport errors were silently dropped because `connection.onError`
    was never assigned. Now routes to `options.onError` callback.
- **Fix: Record CLI process exit code in StdioTransport**
  - Added `lastExitCode` field and `onProcessExit` callback for immediate
    notification when the CLI process terminates.
- Added decoder error logging to StdioTransport stderr buffer.

- **Feature parity with upstream Node.js SDK v0.1.8**
- **P0 wire-format bug fixes:**
  - Fixed `SelectionPosition.column` → `character` to match upstream wire format
  - Fixed `MessageOptions.mode` to use `MessageDeliveryMode` (`enqueue`/`immediate`) instead of `AgentMode`
  - Fixed `SessionLifecycleEventType.fromString()` to handle `session.` prefix (CLI sends `"session.created"`)
  - Rewrote all hook types to match upstream field names: `decision`→`permissionDecision`, `updatedArguments`→`modifiedArgs`, `updatedResult`→`modifiedResult`, `updatedPrompt`→`modifiedPrompt`
  - Added `BaseHookInput` with `timestamp`/`cwd` fields, all hook inputs extend it
  - Added `SessionStartOutput`, `SessionEndOutput`, `ErrorOccurredOutput` types
  - Added `additionalContext`/`suppressOutput` to all hook outputs
- **P1 features:**
  - Added dynamic handler registration: `registerPermissionHandler()`, `registerUserInputHandler()`, `registerHooks()`
  - Added `autoStart` — sessions auto-call `start()` when `autoStart: true` (default)
  - Added `sendMessage(MessageOptions)` overload matching upstream API
- Added `workspacePath` to `CopilotSession` (returned from session.create/resume)
- Added agent management RPCs: `listAgents()`, `getCurrentAgent()`, `selectAgent()`, `deselectAgent()`
- Added compaction RPC: `compact()` → `CompactionResult`
- Added client methods: `forceStop()`, `getLastSessionId()`, `getForegroundSessionId()`, `setForegroundSessionId()`
- Added lifecycle event subscription: `onLifecycleEvent()` with typed filtering
- Fixed session.create to include capability flags (`requestPermission`, `requestUserInput`, `hooks`, `envValueMode`)
- Fixed `mcpServers` wire format from `List` to `Map<String, McpServerConfig>` (matches upstream)
- Fixed `resumeSession()` to forward all config fields (was only sending `sessionId`)
- Refactored `McpServerConfig` to sealed hierarchy: `McpLocalServerConfig` / `McpRemoteServerConfig`
- Refactored `Attachment` to sealed hierarchy: `FileAttachment` / `DirectoryAttachment` / `SelectionAttachment`
- Added `InfiniteSessionConfig` class (replaces `bool?` for `infiniteSessions`)
- Added `ToolBinaryResult` for binary tool results
- Added `AgentInfo`, `CompactionResult`, `SessionLifecycleEvent` types
- Added `AzureProviderOptions`, `wireApi`, `bearerToken` to `ProviderConfig`
- Added `ReasoningEffort.xhigh` enum value
- Added structured `kind`/`toolCallId` fields to `PermissionRequest`
- Expanded `ResumeSessionConfig` to 22 fields matching upstream
- Added `registerTools()` batch convenience method to `CopilotSession`
- 45+ session event types (up from 25)

## 0.1.0

- Initial release
- JSON-RPC 2.0 transport layer with Content-Length framing
- Pluggable transports: stdio, TCP, WebSocket
- `CopilotClient` with process lifecycle management
- `CopilotSession` with event handling and tool dispatch
- 25+ typed session events using Dart 3 sealed classes
- Custom tool registration with typed results
- 6 lifecycle hooks (preToolUse, postToolUse, userPromptSubmitted, sessionStart, sessionEnd, errorOccurred)
- Permission and user input request handlers
- Session RPC: model, mode, plan, workspace, fleet
- Full serialization/deserialization for all protocol types
- Comprehensive test suite (317+ tests)
