/// Connection state of the Copilot client.
enum ConnectionState {
  /// Not connected to the CLI server.
  disconnected,

  /// Currently connecting to the CLI server.
  connecting,

  /// Connected and ready.
  connected,

  /// Connection error occurred.
  error,
}
