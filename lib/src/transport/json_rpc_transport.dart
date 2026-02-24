import 'dart:async';

/// Abstract interface for JSON-RPC transports.
///
/// Implementations provide the physical transport layer (stdio, TCP, WebSocket)
/// while the [JsonRpcConnection] handles the JSON-RPC 2.0 protocol on top.
abstract class JsonRpcTransport {
  /// Stream of incoming JSON-RPC messages (already decoded from JSON).
  Stream<Map<String, dynamic>> get messages;

  /// Sends a JSON-RPC message (will be encoded to JSON by the transport).
  Future<void> send(Map<String, dynamic> message);

  /// Closes the transport and releases resources.
  Future<void> close();

  /// Whether the transport is currently connected/open.
  bool get isOpen;
}
