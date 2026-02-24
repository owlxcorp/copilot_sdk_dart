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
  });

  /// Path to the CLI executable. If null, searches PATH for 'copilot'.
  final String? cliPath;

  /// Extra arguments to pass to the CLI executable.
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
