/// Copilot SDK for Dart — main barrel export.
///
/// This export includes all transport-agnostic types, the client, and session.
/// For platform-specific transports:
/// - Desktop/server: `import 'package:copilot_sdk_dart/copilot_sdk_io.dart'`
/// - Web: `import 'package:copilot_sdk_dart/copilot_sdk_web.dart'`
library;

export 'src/client.dart';
export 'src/session.dart';
export 'src/transport/json_rpc_connection.dart' show JsonRpcError;
export 'src/transport/json_rpc_transport.dart';
export 'src/types/auth_types.dart';
export 'src/types/client_options.dart';
export 'src/types/connection_state.dart';
export 'src/types/hooks.dart';
export 'src/types/session_config.dart';
export 'src/types/session_event.dart';
export 'src/types/tool_types.dart';
