import 'dart:async';

import 'package:copilot_sdk_dart/src/transport/json_rpc_transport.dart';

/// In-memory transport for testing JSON-RPC connections.
///
/// Provides two linked transports: messages sent on one appear on the other.
class MockTransportPair {
  MockTransportPair() {
    _clientToServer = StreamController<Map<String, dynamic>>.broadcast();
    _serverToClient = StreamController<Map<String, dynamic>>.broadcast();

    client = MockTransport(
      messageStream: _serverToClient.stream,
      sendSink: _clientToServer,
    );
    server = MockTransport(
      messageStream: _clientToServer.stream,
      sendSink: _serverToClient,
    );
  }

  late final StreamController<Map<String, dynamic>> _clientToServer;
  late final StreamController<Map<String, dynamic>> _serverToClient;

  late final MockTransport client;
  late final MockTransport server;

  Future<void> close() async {
    await client.close();
    await server.close();
    await _clientToServer.close();
    await _serverToClient.close();
  }
}

/// A mock transport backed by stream controllers.
class MockTransport implements JsonRpcTransport {
  MockTransport({
    required Stream<Map<String, dynamic>> messageStream,
    required StreamController<Map<String, dynamic>> sendSink,
  })  : _messageStream = messageStream,
        _sendSink = sendSink;

  final Stream<Map<String, dynamic>> _messageStream;
  final StreamController<Map<String, dynamic>> _sendSink;
  bool _isOpen = true;

  /// Messages that were sent via this transport (for assertions).
  final List<Map<String, dynamic>> sentMessages = [];

  @override
  Stream<Map<String, dynamic>> get messages => _messageStream;

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_isOpen) throw StateError('Transport is closed');
    sentMessages.add(message);
    _sendSink.add(message);
  }

  @override
  Future<void> close() async {
    _isOpen = false;
    // Close the sink so the other side's stream ends (triggering onDone)
    await _sendSink.close();
  }

  @override
  bool get isOpen => _isOpen;
}
