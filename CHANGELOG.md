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
