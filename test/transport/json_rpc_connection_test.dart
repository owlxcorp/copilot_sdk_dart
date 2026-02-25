import 'dart:async';

import 'package:copilot_sdk_dart/src/transport/json_rpc_connection.dart';
import 'package:test/test.dart';

import 'mock_transport.dart';

void main() {
  group('JsonRpcConnection', () {
    late MockTransportPair pair;
    late JsonRpcConnection clientConn;
    late JsonRpcConnection serverConn;

    setUp(() {
      pair = MockTransportPair();
      clientConn = JsonRpcConnection(pair.client);
      serverConn = JsonRpcConnection(pair.server);
    });

    tearDown(() async {
      await clientConn.close();
      await serverConn.close();
      await pair.close();
    });

    group('request/response', () {
      test('sends request and receives response', () async {
        // Server handles 'ping' requests
        serverConn.registerRequestHandler('ping', (params) async {
          return {'message': 'pong', 'timestamp': 12345};
        });

        final result = await clientConn.sendRequest('ping', {'message': 'hi'});

        expect(result, isA<Map<String, dynamic>>());
        expect(result['message'], equals('pong'));
        expect(result['timestamp'], equals(12345));
      });

      test('handles request with null params', () async {
        serverConn.registerRequestHandler('status', (params) async {
          return {'version': '1.0.0'};
        });

        final result = await clientConn.sendRequest('status');
        expect(result['version'], equals('1.0.0'));
      });

      test('propagates error responses', () async {
        serverConn.registerRequestHandler('fail', (params) async {
          throw Exception('Something went wrong');
        });

        expect(
          () => clientConn.sendRequest('fail'),
          throwsA(isA<JsonRpcError>()),
        );
      });

      test('returns method not found for unknown methods', () async {
        expect(
          () => clientConn.sendRequest('unknown_method'),
          throwsA(
            isA<JsonRpcError>().having(
              (e) => e.code,
              'code',
              equals(-32601),
            ),
          ),
        );
      });

      test('handles timeout', () async {
        serverConn.registerRequestHandler('slow', (params) async {
          await Future<void>.delayed(const Duration(seconds: 5));
          return {'done': true};
        });

        expect(
          () => clientConn.sendRequest(
            'slow',
            null,
            const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('preserves JsonRpcError code and message from handler', () async {
        // Handlers that throw JsonRpcError should propagate the exact code/message,
        // not be wrapped in the generic -32603 Internal error.
        serverConn.registerRequestHandler('strict.method', (params) async {
          throw const JsonRpcError(
              code: -32602, message: 'Invalid params: missing field');
        });

        await expectLater(
          () => clientConn.sendRequest('strict.method'),
          throwsA(
            isA<JsonRpcError>()
                .having((e) => e.code, 'code', equals(-32602))
                .having(
                  (e) => e.message,
                  'message',
                  contains('Invalid params'),
                ),
          ),
        );
      });
    });

    group('bidirectional requests', () {
      test('server can send requests to client', () async {
        clientConn.registerRequestHandler('tool.call', (params) async {
          final toolName = (params as Map<String, dynamic>)['toolName'];
          return {'result': 'executed $toolName'};
        });

        final result = await serverConn.sendRequest('tool.call', {
          'toolName': 'bash',
          'arguments': {'command': 'ls'},
        });

        expect(result['result'], equals('executed bash'));
      });

      test('concurrent bidirectional requests', () async {
        clientConn.registerRequestHandler('clientMethod', (params) async {
          return {'from': 'client'};
        });
        serverConn.registerRequestHandler('serverMethod', (params) async {
          return {'from': 'server'};
        });

        // Send requests in both directions simultaneously
        final results = await Future.wait([
          clientConn.sendRequest('serverMethod'),
          serverConn.sendRequest('clientMethod'),
        ]);

        expect(results[0]['from'], equals('server'));
        expect(results[1]['from'], equals('client'));
      });
    });

    group('notifications', () {
      test('sends and receives notifications', () async {
        final received = Completer<Map<String, dynamic>>();

        serverConn.registerNotificationHandler('session.event', (params) {
          received.complete(params as Map<String, dynamic>);
        });

        await clientConn.sendNotification('session.event', {
          'type': 'assistant.message',
          'data': {'content': 'Hello'},
        });

        final result = await received.future.timeout(
          const Duration(seconds: 2),
        );
        expect(result['type'], equals('assistant.message'));
      });

      test('general notification handler receives all notifications', () async {
        final received = <String>[];
        final done = Completer<void>();

        serverConn.onNotification = (method, params) {
          received.add(method);
          if (received.length == 2) done.complete();
        };

        await clientConn.sendNotification('event.a', <String, dynamic>{});
        await clientConn.sendNotification('event.b', <String, dynamic>{});

        await done.future.timeout(const Duration(seconds: 2));
        expect(received, equals(['event.a', 'event.b']));
      });
    });

    group('lifecycle', () {
      test('throws when sending on closed connection', () async {
        await clientConn.close();

        expect(
          () => clientConn.sendRequest('ping'),
          throwsA(isA<StateError>()),
        );
      });

      test('fails pending requests on close', () async {
        serverConn.registerRequestHandler('slow', (params) async {
          await Future<void>.delayed(const Duration(seconds: 10));
          return {};
        });

        final future = clientConn.sendRequest(
          'slow',
          null,
          const Duration(seconds: 10),
        );

        // Attach error handler before closing to avoid unhandled error
        Object? caughtError;
        unawaited(future.then((_) {}).catchError((Object e) {
          caughtError = e;
        }));

        // Give a moment for the request to be sent
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Close while request is pending
        await clientConn.close();

        // Wait for the error to propagate
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(caughtError, isA<StateError>());
      });

      test('calls onClose callback', () async {
        final closed = Completer<void>();
        clientConn.onClose = () => closed.complete();

        await clientConn.close();

        await closed.future.timeout(const Duration(seconds: 1));
      });

      test('remove handlers', () async {
        serverConn.registerRequestHandler('temp', (params) async => 'ok');

        // Works before removal
        final result = await clientConn.sendRequest('temp');
        expect(result, equals('ok'));

        // Remove and verify it fails
        serverConn.removeRequestHandler('temp');
        expect(
          () => clientConn.sendRequest('temp'),
          throwsA(isA<JsonRpcError>()),
        );
      });
    });
  });
}
