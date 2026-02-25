import 'dart:async';

import 'package:uuid/uuid.dart';

import 'json_rpc_transport.dart';

/// A bidirectional JSON-RPC 2.0 connection.
///
/// Handles:
/// - Sending requests and correlating responses via ID
/// - Receiving requests from the remote side and dispatching to handlers
/// - Receiving notifications (no ID) and dispatching to handlers
/// - Request timeout management
class JsonRpcConnection {
  JsonRpcConnection(this._transport, {this.log}) {
    _subscription = _transport.messages.listen(
      _handleMessage,
      onError: _handleError,
      onDone: _handleDone,
    );
  }

  final JsonRpcTransport _transport;
  final _uuid = const Uuid();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  /// Optional log callback for diagnostic messages.
  final void Function(String message)? log;

  /// Pending outgoing requests awaiting a response, keyed by request ID.
  final Map<String, Completer<dynamic>> _pendingRequests = {};

  /// Handlers for incoming requests from the remote side, keyed by method.
  final Map<String, Future<dynamic> Function(dynamic params)> _requestHandlers =
      {};

  /// Handlers for incoming notifications, keyed by method.
  final Map<String, void Function(dynamic params)> _notificationHandlers = {};

  /// General notification handler (receives all notifications).
  void Function(String method, dynamic params)? onNotification;

  /// Called when the connection is closed.
  void Function()? onClose;

  /// Called when a connection error occurs.
  void Function(Object error)? onError;

  bool _isClosed = false;

  /// Whether the connection has been closed.
  bool get isClosed => _isClosed;

  /// Sends a JSON-RPC request and waits for the response.
  ///
  /// Returns the `result` field from the response, or throws a
  /// [JsonRpcError] if the response contains an error.
  Future<dynamic> sendRequest(
    String method, [
    dynamic params,
    Duration timeout = const Duration(seconds: 60),
  ]) async {
    if (_isClosed) {
      throw StateError('Connection is closed');
    }

    final id = _uuid.v4();
    final request = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
    };
    if (params != null) {
      request['params'] = params;
    }

    final completer = Completer<dynamic>();
    _pendingRequests[id] = completer;

    try {
      await _transport.send(request);
    } catch (e) {
      _pendingRequests.remove(id);
      rethrow;
    }

    // Apply timeout
    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pendingRequests.remove(id);
        throw TimeoutException(
          'JSON-RPC request "$method" timed out after ${timeout.inSeconds}s',
          timeout,
        );
      },
    );
  }

  /// Sends a JSON-RPC notification (no response expected).
  Future<void> sendNotification(String method, [dynamic params]) async {
    if (_isClosed) {
      throw StateError('Connection is closed');
    }

    final notification = <String, dynamic>{
      'jsonrpc': '2.0',
      'method': method,
    };
    if (params != null) {
      notification['params'] = params;
    }

    await _transport.send(notification);
  }

  /// Registers a handler for incoming requests with the given method.
  ///
  /// The handler receives the `params` field and should return the result.
  /// If the handler throws, an error response is sent back.
  void registerRequestHandler(
    String method,
    Future<dynamic> Function(dynamic params) handler,
  ) {
    _requestHandlers[method] = handler;
  }

  /// Registers a handler for incoming notifications with the given method.
  void registerNotificationHandler(
    String method,
    void Function(dynamic params) handler,
  ) {
    _notificationHandlers[method] = handler;
  }

  /// Removes a request handler.
  void removeRequestHandler(String method) {
    _requestHandlers.remove(method);
  }

  /// Removes a notification handler.
  void removeNotificationHandler(String method) {
    _notificationHandlers.remove(method);
  }

  /// Closes the connection and cancels all pending requests.
  Future<void> close() async {
    if (_isClosed) return;
    _isClosed = true;

    await _subscription?.cancel();
    _subscription = null;

    // Fail all pending requests
    for (final entry in _pendingRequests.entries) {
      entry.value.completeError(
        StateError('Connection closed while awaiting response to ${entry.key}'),
      );
    }
    _pendingRequests.clear();

    await _transport.close();
    onClose?.call();
  }

  void _handleMessage(Map<String, dynamic> message) {
    // Determine if this is a request, response, or notification
    final hasId = message.containsKey('id');
    final hasMethod = message.containsKey('method');
    final hasResult = message.containsKey('result');
    final hasError = message.containsKey('error');

    if (hasId && (hasResult || hasError)) {
      // This is a response to one of our requests
      _handleResponse(message);
    } else if (hasMethod && hasId) {
      // This is a request from the remote side
      log?.call('RPC: ← request ${message['method']} (id=${message['id']})');
      _handleIncomingRequest(message);
    } else if (hasMethod && !hasId) {
      // This is a notification
      log?.call('RPC: ← notification ${message['method']}');
      _handleNotification(message);
    } else {
      log?.call('RPC: ← unknown message format: ${message.keys.join(', ')}');
    }
  }

  void _handleResponse(Map<String, dynamic> message) {
    final id = message['id']?.toString();
    if (id == null) return;

    final completer = _pendingRequests.remove(id);
    if (completer == null) return; // Stale response, ignore

    if (message.containsKey('error')) {
      final error = message['error'];
      completer.completeError(JsonRpcError.fromJson(error));
    } else {
      completer.complete(message['result']);
    }
  }

  Future<void> _handleIncomingRequest(Map<String, dynamic> message) async {
    final id = message['id'];
    final method = message['method'] as String;
    final params = message['params'];

    log?.call('RPC: incoming request → $method (id=$id)');

    final handler = _requestHandlers[method];
    if (handler == null) {
      log?.call('RPC: method not found → $method');
      // Method not found
      await _sendResponse(id, error: {
        'code': -32601,
        'message': 'Method not found: $method',
      });
      return;
    }

    try {
      final result = await handler(params);
      log?.call('RPC: request handled → $method (id=$id)');
      await _sendResponse(id, result: result);
    } catch (e) {
      log?.call('RPC: request error → $method: $e');
      if (e is JsonRpcError) {
        await _sendResponse(id, error: {
          'code': e.code,
          'message': e.message,
          if (e.data != null) 'data': e.data,
        });
      } else {
        await _sendResponse(id, error: {
          'code': -32603,
          'message': 'Internal error: $e',
        });
      }
    }
  }

  void _handleNotification(Map<String, dynamic> message) {
    final method = message['method'] as String;
    final params = message['params'];

    final handler = _notificationHandlers[method];
    if (handler != null) {
      try {
        handler(params);
      } catch (e) {
        // Notification handler errors must not kill the transport stream.
        onError?.call(e);
      }
    }

    try {
      onNotification?.call(method, params);
    } catch (e) {
      onError?.call(e);
    }
  }

  Future<void> _sendResponse(
    dynamic id, {
    dynamic result,
    Map<String, dynamic>? error,
  }) async {
    if (_isClosed) return;

    final response = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
    };
    if (error != null) {
      response['error'] = error;
    } else {
      response['result'] = result;
    }

    try {
      await _transport.send(response);
    } catch (e) {
      // Send failures must not crash the connection — the remote side
      // will time out the request. Log via the error callback.
      onError?.call(e);
    }
  }

  void _handleError(Object error) {
    onError?.call(error);
  }

  void _handleDone() {
    if (!_isClosed) {
      _isClosed = true;
      // Fail all pending requests
      for (final entry in _pendingRequests.entries) {
        entry.value.completeError(
          StateError(
            'Transport closed unexpectedly while awaiting ${entry.key}',
          ),
        );
      }
      _pendingRequests.clear();
      onClose?.call();
    }
  }
}

/// Error received in a JSON-RPC error response.
class JsonRpcError implements Exception {
  const JsonRpcError({
    required this.code,
    required this.message,
    this.data,
  });

  factory JsonRpcError.fromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return JsonRpcError(
        code: json['code'] as int? ?? -32603,
        message: json['message'] as String? ?? 'Unknown error',
        data: json['data'],
      );
    }
    return JsonRpcError(
      code: -32603,
      message: json?.toString() ?? 'Unknown error',
    );
  }

  final int code;
  final String message;
  final dynamic data;

  @override
  String toString() => 'JsonRpcError($code): $message';

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}
