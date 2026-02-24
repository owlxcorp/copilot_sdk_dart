import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

/// Encodes and decodes JSON-RPC messages with Content-Length framing.
///
/// Uses the LSP-style protocol:
/// ```
/// Content-Length: <byte_length>\r\n
/// \r\n
/// <json_payload>
/// ```
class ContentLengthCodec {
  ContentLengthCodec({
    this.maxMessageBytes = 64 * 1024 * 1024,
    this.maxHeaderBytes = 16 * 1024,
  })  : assert(maxMessageBytes > 0),
        assert(maxHeaderBytes > 0);

  /// Maximum allowed JSON body size in bytes.
  final int maxMessageBytes;

  /// Maximum allowed header size in bytes.
  final int maxHeaderBytes;

  /// Encodes a JSON object into a Content-Length framed byte sequence.
  List<int> encode(Map<String, dynamic> message) {
    final json = jsonEncode(message);
    final body = utf8.encode(json);
    final header = utf8.encode('Content-Length: ${body.length}\r\n\r\n');
    return [...header, ...body];
  }

  /// Creates a [StreamTransformer] that decodes a byte stream into
  /// individual JSON-RPC messages.
  StreamTransformer<List<int>, Map<String, dynamic>> get decoder =>
      StreamTransformer.fromBind(_decodeStream);

  Stream<Map<String, dynamic>> _decodeStream(Stream<List<int>> input) {
    return _ContentLengthDecoder(
      input,
      maxMessageBytes: maxMessageBytes,
      maxHeaderBytes: maxHeaderBytes,
    ).stream;
  }
}

/// Internal stateful decoder that buffers incoming bytes and extracts
/// Content-Length framed JSON-RPC messages.
class _ContentLengthDecoder {
  _ContentLengthDecoder(
    Stream<List<int>> input, {
    required int maxMessageBytes,
    required int maxHeaderBytes,
  })  : _maxMessageBytes = maxMessageBytes,
        _maxHeaderBytes = maxHeaderBytes {
    _controller = StreamController<Map<String, dynamic>>(
      onCancel: () => _subscription?.cancel(),
    );
    _subscription = input.listen(
      _onData,
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  late final StreamController<Map<String, dynamic>> _controller;
  StreamSubscription<List<int>>? _subscription;
  final _buffer = BytesBuilder(copy: false);
  int? _expectedLength;
  final int _maxMessageBytes;
  final int _maxHeaderBytes;

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void _onData(List<int> chunk) {
    if (_buffer.length + chunk.length > _maxMessageBytes) {
      _failAndStop(
        FormatException(
          'Buffered data exceeds maximum of $_maxMessageBytes bytes',
        ),
      );
      return;
    }
    _buffer.add(chunk);
    _processBuffer();
  }

  void _processBuffer() {
    while (true) {
      if (_expectedLength == null) {
        if (_buffer.length > _maxHeaderBytes) {
          _failAndStop(
            FormatException(
              'Content-Length header exceeds maximum of $_maxHeaderBytes bytes',
            ),
          );
          return;
        }

        // Look for header
        final bytes = _buffer.toBytes();
        final headerEnd = _findHeaderEnd(bytes);
        if (headerEnd == -1) return;

        final headerStr = utf8.decode(bytes.sublist(0, headerEnd));
        _expectedLength = _parseContentLength(headerStr);
        if (_expectedLength == null) {
          _failAndStop(
            FormatException('Invalid Content-Length header: $headerStr'),
          );
          return;
        }

        if (_expectedLength! > _maxMessageBytes) {
          _failAndStop(
            FormatException(
              'Content-Length $_expectedLength exceeds maximum of '
              '$_maxMessageBytes bytes',
            ),
          );
          return;
        }

        // Remove header from buffer (headerEnd + 4 for \r\n\r\n)
        final remaining = bytes.sublist(headerEnd + 4);
        _buffer.clear();
        if (remaining.isNotEmpty) {
          _buffer.add(remaining);
        }
      }

      // Check if we have enough data for the body
      final length = _expectedLength!;
      if (_buffer.length > _maxMessageBytes) {
        _failAndStop(
          FormatException(
            'Buffered message exceeds maximum of $_maxMessageBytes bytes',
          ),
        );
        return;
      }
      if (_buffer.length < length) return;

      final bytes = _buffer.toBytes();
      final body = bytes.sublist(0, length);
      final remaining = bytes.sublist(length);

      _buffer.clear();
      if (remaining.isNotEmpty) {
        _buffer.add(remaining);
      }
      _expectedLength = null;

      try {
        final json = utf8.decode(body);
        final message = jsonDecode(json) as Map<String, dynamic>;
        _controller.add(message);
      } catch (e) {
        _controller.addError(
          FormatException('Failed to parse JSON-RPC message: $e'),
        );
      }
    }
  }

  void _failAndStop(FormatException error) {
    _controller.addError(error);
    _buffer.clear();
    _expectedLength = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_controller.close());
  }

  /// Finds the index of the start of \r\n\r\n in the byte array.
  /// Returns -1 if not found.
  int _findHeaderEnd(Uint8List bytes) {
    // Looking for \r\n\r\n (0x0D 0x0A 0x0D 0x0A)
    for (var i = 0; i < bytes.length - 3; i++) {
      if (bytes[i] == 0x0D &&
          bytes[i + 1] == 0x0A &&
          bytes[i + 2] == 0x0D &&
          bytes[i + 3] == 0x0A) {
        return i;
      }
    }
    return -1;
  }

  /// Parses the Content-Length value from the header string.
  int? _parseContentLength(String header) {
    for (final line in header.split('\r\n')) {
      final trimmed = line.trim();
      if (trimmed.toLowerCase().startsWith('content-length:')) {
        final value = trimmed.substring('content-length:'.length).trim();
        return int.tryParse(value);
      }
    }
    return null;
  }
}
