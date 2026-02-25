import 'dart:async';
import 'dart:io';

import 'package:copilot_sdk_dart/src/client.dart';
import 'package:copilot_sdk_dart/src/transport/content_length_codec.dart';
import 'package:copilot_sdk_dart/src/types/client_options.dart';
import 'package:copilot_sdk_dart/src/types/session_config.dart';
import 'package:copilot_sdk_dart/src/types/tool_types.dart';
import 'package:test/test.dart';

import 'helpers/fake_server.dart';

void main() {
  group('Local MCP server', () {
    test('supports initialize, tools/list, and tools/call', () async {
      final mcp = _LocalMcpClient();
      await mcp.start();
      addTearDown(mcp.close);

      final initialize = await mcp.request(
        'initialize',
        params: {
          'protocolVersion': '2024-11-05',
          'capabilities': <String, dynamic>{},
          'clientInfo': {
            'name': 'sdk-test-client',
            'version': '1.0.0',
          },
        },
      );
      final initializeResult = initialize['result'] as Map<String, dynamic>;
      final serverInfo = initializeResult['serverInfo'] as Map<String, dynamic>;
      expect(serverInfo['name'], 'local-mcp-test-server');
      expect(serverInfo['version'], '1.0.0');

      final listTools = await mcp.request('tools/list');
      final listResult = listTools['result'] as Map<String, dynamic>;
      final tools = listResult['tools'] as List<dynamic>;
      final toolNames =
          tools.map((tool) => (tool as Map<String, dynamic>)['name']).toList();
      expect(toolNames, containsAll(['local_add', 'local_echo']));

      final callTool = await mcp.request(
        'tools/call',
        params: {
          'name': 'local_add',
          'arguments': {'a': 2, 'b': 5},
        },
      );
      final callResult = callTool['result'] as Map<String, dynamic>;
      final content = (callResult['content'] as List<dynamic>).first
          as Map<String, dynamic>;
      expect(content['text'], 'sum=7');
      expect(callResult['isError'], isFalse);
    });
  });

  group('MCP config and custom tools', () {
    test('forwards mcpServers and still executes custom tool handlers',
        () async {
      final mcp = _LocalMcpClient();
      await mcp.start();
      addTearDown(mcp.close);

      final mcpEcho = await mcp.request(
        'tools/call',
        params: {
          'name': 'local_echo',
          'arguments': {'text': 'mcp-ready'},
        },
      );
      final mcpEchoResult = mcpEcho['result'] as Map<String, dynamic>;
      final mcpEchoContent = (mcpEchoResult['content'] as List<dynamic>).first
          as Map<String, dynamic>;
      expect(mcpEchoContent['text'], 'mcp-ready');

      final fakeServer = FakeServer();
      final client = CopilotClient(
        options: const CopilotClientOptions(),
        transport: fakeServer.clientTransport,
      );
      addTearDown(() async {
        try {
          await client.stop();
        } catch (_) {}
        await fakeServer.close();
      });

      await client.start();
      final session = await client.createSession(
        config: SessionConfig(
          mcpServers: {
            'local-mcp-test': McpLocalServerConfig(
              command: Platform.resolvedExecutable,
              args: _mcpServerArgs(),
            ),
          },
          tools: [
            Tool(
              name: 'multiply_numbers',
              parameters: {
                'type': 'object',
                'properties': {
                  'x': {'type': 'number'},
                  'y': {'type': 'number'},
                },
                'required': ['x', 'y'],
              },
              handler: (args, invocation) async {
                final payload = args as Map<String, dynamic>;
                final x = payload['x'] as num;
                final y = payload['y'] as num;
                return ToolResult.success((x * y).toString());
              },
            ),
          ],
          onPermissionRequest: approveAllPermissions,
        ),
      );

      final createParams = fakeServer.lastSessionCreateParams;
      expect(createParams, isNotNull);
      final mcpServers = createParams!['mcpServers'] as Map<String, dynamic>;
      expect(mcpServers, hasLength(1));
      expect(mcpServers.containsKey('local-mcp-test'), isTrue);
      final mcpConfig = mcpServers['local-mcp-test'] as Map<String, dynamic>;
      expect(mcpConfig['command'], Platform.resolvedExecutable);
      expect(
        (mcpConfig['args'] as List<dynamic>).contains(
          'test/helpers/local_mcp_test_server.dart',
        ),
        isTrue,
      );

      final toolCallResponse = await fakeServer.sendToolCallRequest(
        sessionId: session.sessionId,
        toolName: 'multiply_numbers',
        toolCallId: 'tc-local-1',
        arguments: {'x': 6, 'y': 7},
      );
      final toolCallResult = toolCallResponse['result'] as Map<String, dynamic>;
      expect(toolCallResult['resultType'], 'success');
      expect(toolCallResult['textResultForLlm'], '42');
    });
  });
}

List<String> _mcpServerArgs() => [
      '--packages=.dart_tool/package_config.json',
      'test/helpers/local_mcp_test_server.dart',
    ];

class _LocalMcpClient {
  final ContentLengthCodec _codec = ContentLengthCodec();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  Process? _process;
  StreamSubscription<Map<String, dynamic>>? _subscription;
  StreamSubscription<List<int>>? _stderrSubscription;
  int _nextId = 1;

  Future<void> start() async {
    if (_process != null) return;

    _process = await Process.start(
      Platform.resolvedExecutable,
      _mcpServerArgs(),
      workingDirectory: Directory.current.path,
    );

    _subscription = _process!.stdout.transform(_codec.decoder).listen(
      (message) {
        final id = message['id'];
        if (id is! int) return;

        final completer = _pending.remove(id);
        if (completer != null && !completer.isCompleted) {
          completer.complete(message);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        for (final completer in _pending.values) {
          if (!completer.isCompleted) {
            completer.completeError(error, stackTrace);
          }
        }
        _pending.clear();
      },
      onDone: () {
        for (final completer in _pending.values) {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('Local MCP server closed unexpectedly'),
            );
          }
        }
        _pending.clear();
      },
    );

    _stderrSubscription = _process!.stderr.listen((_) {});
  }

  Future<Map<String, dynamic>> request(
    String method, {
    Map<String, dynamic>? params,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final process = _process;
    if (process == null) {
      throw StateError('Local MCP server is not running');
    }

    final id = _nextId++;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;

    process.stdin.add(_codec.encode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      if (params != null) 'params': params,
    }));
    await process.stdin.flush();

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(id);
        throw TimeoutException('Timed out waiting for MCP response: $method');
      },
    );
  }

  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await _stderrSubscription?.cancel();
    _stderrSubscription = null;

    final process = _process;
    _process = null;
    if (process != null) {
      await process.stdin.close();
      process.kill(ProcessSignal.sigterm);
      await process.exitCode.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
    }

    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Local MCP server closed before responding'),
        );
      }
    }
    _pending.clear();
  }
}
