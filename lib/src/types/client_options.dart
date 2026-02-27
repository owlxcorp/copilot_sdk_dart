import 'hooks.dart';
import 'session_config.dart';
import 'tool_types.dart';

/// Options for creating a [CopilotClient].
class CopilotClientOptions {
  const CopilotClientOptions({
    this.cliPath,
    this.cliArgs = const [],
    this.cwd,
    this.port = 0,
    this.useStdio = true,
    this.cliUrl,
    this.logLevel,
    this.autoStart = true,
    this.autoRestart = true,
    this.env,
    this.githubToken,
    this.useLoggedInUser,
    this.log,
    this.tools = const [],
    this.hooks,
    this.onPermissionRequest,
    this.onUserInputRequest,
  });

  /// Path to the CLI executable. If null, searches PATH for 'copilot'.
  final String? cliPath;

  /// Extra arguments to pass to the CLI executable.
  ///
  /// These are prepended before the required flags (`--headless`, `--stdio`,
  /// `--no-auto-update`). Use for flags like `--model`, `--log-level`, etc.
  final List<String> cliArgs;

  /// Working directory for the CLI process.
  final String? cwd;

  /// Port for the CLI server (TCP mode only). 0 = random available port.
  final int port;

  /// Use stdio transport instead of TCP.
  final bool useStdio;

  /// URL of an existing CLI server to connect to (e.g., "localhost:8080").
  /// When set, the client does not spawn a CLI process.
  final String? cliUrl;

  /// Log level for the CLI server.
  final LogLevel? logLevel;

  /// Auto-start the CLI server on first use.
  final bool autoStart;

  /// Auto-restart the CLI server if it crashes.
  final bool autoRestart;

  /// Environment variables for the CLI process.
  final Map<String, String>? env;

  /// GitHub token for authentication.
  final String? githubToken;

  /// Whether to use the logged-in user for authentication.
  final bool? useLoggedInUser;

  /// Optional log callback for SDK diagnostic messages.
  final void Function(String message)? log;

  /// Client-level tools available to all sessions.
  ///
  /// These are merged with session-specific tools when creating sessions.
  /// Session-level tools take priority for handler lookup.
  final List<Tool> tools;

  /// Client-level hooks. Used as fallback when session hooks are not provided.
  final SessionHooks? hooks;

  /// Client-level permission handler. Used as fallback when session config
  /// does not provide one.
  final PermissionHandler? onPermissionRequest;

  /// Client-level user input handler. Used as fallback when session config
  /// does not provide one.
  final UserInputHandler? onUserInputRequest;
}

/// Log levels for the CLI server.
enum LogLevel {
  none,
  error,
  warning,
  info,
  debug,
  all;

  String toJsonValue() => name;
}
