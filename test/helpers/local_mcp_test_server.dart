import 'dart:convert';
import 'dart:io';

import 'package:copilot_sdk_dart/src/transport/content_length_codec.dart';

const _serverName = 'local-mcp-test-server';
const _serverVersion = '1.0.0';

Future<void> main() async {
  final codec = ContentLengthCodec();

  await for (final message in stdin.transform(codec.decoder)) {
    final method = message['method'];
    if (method is! String) {
      continue;
    }

    final id = message['id'];
    final params = message['params'];

    // Notifications do not require a response.
    if (id == null) {
      continue;
    }

    try {
      final result = _handleRequest(method, params);
      _writeFrame(codec, {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      });
    } catch (error) {
      _writeFrame(codec, {
        'jsonrpc': '2.0',
        'id': id,
        'error': {
          'code': -32000,
          'message': error.toString(),
        },
      });
    }
  }
}

Object _handleRequest(String method, dynamic params) {
  switch (method) {
    case 'initialize':
      return {
        'protocolVersion': '2024-11-05',
        'serverInfo': {
          'name': _serverName,
          'version': _serverVersion,
        },
        'capabilities': {
          'tools': <String, dynamic>{},
        },
      };
    case 'tools/list':
      return {
        'tools': [
          {
            'name': 'local_add',
            'description': 'Add two numbers.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'a': {'type': 'number'},
                'b': {'type': 'number'},
              },
              'required': ['a', 'b'],
            },
          },
          {
            'name': 'local_echo',
            'description': 'Echo input text.',
            'inputSchema': {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
              },
              'required': ['text'],
            },
          },
        ],
      };
    case 'tools/call':
      final request = _asMap(params, 'tools/call params');
      final name = request['name'];
      final arguments = _asMap(request['arguments'], 'tools/call arguments');

      if (name == 'local_add') {
        final a = arguments['a'];
        final b = arguments['b'];
        if (a is! num || b is! num) {
          throw ArgumentError('local_add requires numeric a and b');
        }

        return {
          'content': [
            {'type': 'text', 'text': 'sum=${a + b}'},
          ],
          'isError': false,
        };
      }

      if (name == 'local_echo') {
        final text = arguments['text'];
        if (text is! String) {
          throw ArgumentError('local_echo requires text');
        }

        return {
          'content': [
            {'type': 'text', 'text': text},
          ],
          'isError': false,
        };
      }

      throw ArgumentError('Unknown tool: $name');
    default:
      throw UnsupportedError('Unknown method: $method');
  }
}

Map<String, dynamic> _asMap(dynamic value, String label) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return jsonDecode(jsonEncode(value)) as Map<String, dynamic>;
  }
  throw ArgumentError('Invalid $label');
}

void _writeFrame(ContentLengthCodec codec, Map<String, dynamic> payload) {
  stdout.add(codec.encode(payload));
  stdout.flush();
}
