import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'json_rpc_transport.dart';

/// Transport that communicates via WebSocket.
///
/// This is the web-safe transport. It connects to a WebSocket bridge server
/// that relays JSON-RPC messages to/from the Copilot CLI.
///
/// The bridge server is NOT part of this package; it's a separate concern.
/// The bridge simply:
/// 1. Accepts WebSocket connections
/// 2. Spawns or connects to the Copilot CLI
/// 3. Relays Content-Length framed JSON-RPC messages bidirectionally
///
/// Since WebSocket already handles framing, messages over WebSocket
/// are plain JSON strings (no Content-Length framing needed).
class WebSocketTransport implements JsonRpcTransport {
  WebSocketTransport({
    required this.uri,
    this.protocols,
  });

  /// WebSocket URI to connect to (e.g., "ws://localhost:8765").
  final Uri uri;

  /// WebSocket sub-protocols.
  final Iterable<String>? protocols;

  WebSocketChannel? _channel;
  bool _isOpen = false;
  Future<void>? _closeFuture;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamSubscription<dynamic>? _subscription;

  /// Connects to the WebSocket server.
  Future<void> connect() async {
    if (_isOpen) return;

    _channel = WebSocketChannel.connect(uri, protocols: protocols);
    await _channel!.ready;

    _messageController = StreamController<Map<String, dynamic>>.broadcast();

    _subscription = _channel!.stream.listen(
      (data) {
        try {
          final json = jsonDecode(data as String) as Map<String, dynamic>;
          _messageController!.add(json);
        } catch (e) {
          _messageController!.addError(e);
        }
      },
      onError: _messageController!.addError,
      onDone: () {
        _isOpen = false;
        _messageController?.close();
      },
    );

    _isOpen = true;
  }

  @override
  Stream<Map<String, dynamic>> get messages {
    if (_messageController == null) {
      throw StateError('Transport not connected. Call connect() first.');
    }
    return _messageController!.stream;
  }

  @override
  Future<void> send(Map<String, dynamic> message) async {
    if (!_isOpen || _channel == null) {
      throw StateError('Transport is not connected');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  @override
  Future<void> close() {
    final inFlight = _closeFuture;
    if (inFlight != null) return inFlight;
    if (!_isOpen) return Future<void>.value();
    final future = _closeImpl();
    _closeFuture = future;
    return future;
  }

  Future<void> _closeImpl() async {
    _isOpen = false;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    await _messageController?.close();
    _messageController = null;
  }

  @override
  bool get isOpen => _isOpen;
}
