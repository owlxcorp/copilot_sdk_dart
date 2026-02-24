import 'dart:async';
import 'dart:convert';

import 'package:copilot_sdk_dart/src/transport/content_length_codec.dart';
import 'package:test/test.dart';

void main() {
  group('ContentLengthCodec', () {
    late ContentLengthCodec codec;

    setUp(() {
      codec = ContentLengthCodec();
    });

    group('encode', () {
      test('encodes a simple message with correct header', () {
        final message = {'jsonrpc': '2.0', 'method': 'ping'};
        final encoded = codec.encode(message);
        final str = utf8.decode(encoded);

        expect(str, contains('Content-Length:'));
        expect(str, contains('\r\n\r\n'));

        final parts = str.split('\r\n\r\n');
        final header = parts[0];
        final body = parts[1];

        final length = int.parse(header.split(':')[1].trim());
        expect(utf8.encode(body).length, equals(length));
        expect(jsonDecode(body), equals(message));
      });

      test('handles unicode content correctly', () {
        final message = {'text': 'Hello, 世界! 🌍'};
        final encoded = codec.encode(message);
        final str = utf8.decode(encoded);

        final parts = str.split('\r\n\r\n');
        final header = parts[0];
        final body = parts.sublist(1).join('\r\n\r\n');

        // Content-Length is in bytes, not characters
        final declaredLength = int.parse(header.split(':')[1].trim());
        final actualLength = utf8.encode(body).length;
        expect(actualLength, equals(declaredLength));
      });
    });

    group('decoder', () {
      test('decodes a single message', () async {
        final message = {'jsonrpc': '2.0', 'id': '1', 'method': 'test'};
        final encoded = codec.encode(message);

        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        controller.add(encoded);
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(1));
        expect(results[0], equals(message));
      });

      test('decodes multiple messages in one chunk', () async {
        final msg1 = {'jsonrpc': '2.0', 'id': '1', 'method': 'ping'};
        final msg2 = {'jsonrpc': '2.0', 'id': '2', 'method': 'pong'};

        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        // Send both messages as one chunk
        controller.add([...codec.encode(msg1), ...codec.encode(msg2)]);
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(2));
        expect(results[0], equals(msg1));
        expect(results[1], equals(msg2));
      });

      test('handles messages split across chunks', () async {
        final message = {
          'jsonrpc': '2.0',
          'id': 'abc',
          'method': 'test',
          'params': {'key': 'value'},
        };
        final encoded = codec.encode(message);

        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        // Split the encoded bytes into small chunks
        final chunkSize = 5;
        for (var i = 0; i < encoded.length; i += chunkSize) {
          final end =
              (i + chunkSize < encoded.length) ? i + chunkSize : encoded.length;
          controller.add(encoded.sublist(i, end));
        }
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(1));
        expect(results[0], equals(message));
      });

      test('handles interleaved partial messages', () async {
        final msg1 = {'jsonrpc': '2.0', 'id': '1'};
        final msg2 = {'jsonrpc': '2.0', 'id': '2'};
        final enc1 = codec.encode(msg1);
        final enc2 = codec.encode(msg2);

        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        // Split msg1 halfway, then send rest of msg1 + all of msg2
        final mid = enc1.length ~/ 2;
        controller.add(enc1.sublist(0, mid));
        controller.add([...enc1.sublist(mid), ...enc2]);
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(2));
        expect(results[0], equals(msg1));
        expect(results[1], equals(msg2));
      });

      test('handles empty params', () async {
        final message = {
          'jsonrpc': '2.0',
          'id': '1',
          'method': 'test',
          'params': <String, dynamic>{},
        };
        final encoded = codec.encode(message);

        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        controller.add(encoded);
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(1));
        expect(results[0]['params'], isEmpty);
      });

      test('rejects oversized content length', () async {
        final guardedCodec = ContentLengthCodec(maxMessageBytes: 8);
        final controller = StreamController<List<int>>();
        final stream = controller.stream.transform(guardedCodec.decoder);

        final expectation = expectLater(
          stream,
          emitsError(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exceeds maximum'),
            ),
          ),
        );

        controller.add(utf8.encode('Content-Length: 9\r\n\r\n123456789'));
        await controller.close();
        await expectation;
      });

      test('rejects oversized header without delimiter', () async {
        final guardedCodec = ContentLengthCodec(maxHeaderBytes: 8);
        final controller = StreamController<List<int>>();
        final stream = controller.stream.transform(guardedCodec.decoder);

        final expectation = expectLater(
          stream,
          emitsError(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('header exceeds maximum'),
            ),
          ),
        );

        controller.add(utf8.encode('Content-Length: 1'));
        await controller.close();
        await expectation;
      });

      test('rejects incremental body chunks that grow buffer beyond max',
          () async {
        // Verifies the _onData guard prevents unbounded buffer growth when
        // data arrives in small chunks below maxMessageBytes individually
        // but exceeds it collectively.
        final guardedCodec = ContentLengthCodec(maxMessageBytes: 10);
        final controller = StreamController<List<int>>();
        final stream = controller.stream.transform(guardedCodec.decoder);

        final expectation = expectLater(
          stream,
          emitsError(
            isA<FormatException>().having(
              (e) => e.message,
              'message',
              contains('exceeds maximum'),
            ),
          ),
        );

        // 4 × 3 bytes = 12 > maxMessageBytes=10; each chunk is individually fine
        controller.add([1, 2, 3]);
        controller.add([4, 5, 6]);
        controller.add([7, 8, 9]);
        controller.add([10, 11, 12]); // pushes total to 13 > 10 → guard fires
        await controller.close();
        await expectation;
      });
    });

    group('round-trip', () {
      test('encode then decode preserves message', () async {
        final original = {
          'jsonrpc': '2.0',
          'id': 'test-123',
          'method': 'session.create',
          'params': {
            'model': 'gpt-4',
            'systemMessage': {'mode': 'append', 'content': 'Be helpful'},
            'tools': [
              {'name': 'bash', 'description': 'Run bash commands'},
            ],
          },
        };

        final encoded = codec.encode(original);
        final controller = StreamController<List<int>>();
        final decoded = controller.stream.transform(codec.decoder).toList();

        controller.add(encoded);
        await controller.close();

        final results = await decoded;
        expect(results, hasLength(1));
        expect(results[0], equals(original));
      });
    });
  });
}
