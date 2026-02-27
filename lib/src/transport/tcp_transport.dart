import 'dart:async';
import 'dart:io';

import 'content_length_codec.dart';
import 'json_rpc_transport.dart';

/// Transport that communicates with the Copilot CLI server over TCP.
///
/// Connects to a running CLI server at the specified host:port and
/// communicates via Content-Length framed JSON-RPC messages.
class TcpTransport implements JsonRpcTransport {
  /// Creates a TCP transport that connects to [host]:[port].
  ///
  /// The optional [connectionTimeout] defaults to 10 seconds.
  TcpTransport({
    required this.host,
    required this.port,
    this.connectionTimeout = const Duration(seconds: 10),
  });

  /// The hostname or IP address of the Copilot CLI server.
  final String host;

  /// The TCP port of the Copilot CLI server.
  final int port;

  /// Maximum time to wait when establishing the TCP connection.
  final Duration connectionTimeout;
  final ContentLengthCodec _codec = ContentLengthCodec();

  Socket? _socket;
  bool _isOpen = false;
  Future<void>? _closeFuture;
  StreamController<Map<String, dynamic>>? _messageController;
  StreamSubscription<dynamic>? _subscription;

  /// Connects to the TCP server.
  Future<void> connect() async {
    if (_isOpen) return;

    _socket = await Socket.connect(host, port, timeout: connectionTimeout);
    _messageController = StreamController<Map<String, dynamic>>.broadcast();

    _subscription = _socket!.cast<List<int>>().transform(_codec.decoder).listen(
      (msg) => _messageController!.add(msg),
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
    if (!_isOpen || _socket == null) {
      throw StateError('Transport is not connected');
    }
    final encoded = _codec.encode(message);
    _socket!.add(encoded);
    await _socket!.flush();
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

    await _socket?.close();
    _socket = null;

    await _messageController?.close();
    _messageController = null;
  }

  @override
  bool get isOpen => _isOpen;
}
