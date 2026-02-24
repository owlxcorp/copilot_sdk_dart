import 'dart:async';

import 'package:copilot_sdk_dart/src/transport/json_rpc_connection.dart';

import '../transport/mock_transport.dart';

/// A fake Copilot CLI server that runs over a MockTransport.
///
/// Simulates the server side of the JSON-RPC 2.0 protocol for testing
/// the CopilotClient and CopilotSession without spawning a real CLI process.
class FakeServer {
  FakeServer() {
    pair = MockTransportPair();
    connection = JsonRpcConnection(pair.server);
    _registerDefaults();
  }

  late final MockTransportPair pair;
  late final JsonRpcConnection connection;

  int _sessionCounter = 0;
  final Map<String, FakeSession> sessions = {};
  Map<String, dynamic>? lastSessionCreateParams;

  /// The client-side transport for use with CopilotClient.
  MockTransport get clientTransport => pair.client;

  /// Register default RPC handlers that mimic the Copilot CLI.
  void _registerDefaults() {
    connection.registerRequestHandler('ping', (params) async {
      return {'protocolVersion': 2};
    });

    connection.registerRequestHandler('status.get', (params) async {
      return {'version': '1.0.0-fake', 'protocolVersion': 2};
    });

    connection.registerRequestHandler('auth.getStatus', (params) async {
      return {
        'isAuthenticated': true,
        'authType': 'oauth',
        'host': 'github.com',
        'login': 'testuser',
      };
    });

    connection.registerRequestHandler('models.list', (params) async {
      return {
        'models': [
          {
            'id': 'gpt-4',
            'name': 'GPT-4',
            'capabilities': {
              'supports': {'vision': true, 'reasoningEffort': true},
              'limits': {'max_context_window_tokens': 128000},
            },
          },
          {
            'id': 'claude-sonnet',
            'name': 'Claude Sonnet',
            'capabilities': {
              'supports': {'vision': false, 'reasoningEffort': false},
              'limits': {'max_context_window_tokens': 200000},
            },
          },
        ],
      };
    });

    connection.registerRequestHandler('tools.list', (params) async {
      return {
        'tools': [
          {'name': 'bash', 'description': 'Run bash commands'},
          {'name': 'read_file', 'description': 'Read a file'},
        ],
      };
    });

    connection.registerRequestHandler('account.getQuota', (params) async {
      return {
        'quotaSnapshots': {
          'copilot': {
            'entitlementRequests': 1000,
            'usedRequests': 250,
            'remainingPercentage': 75.0,
            'overage': 0,
            'overageAllowedWithExhaustedQuota': false,
          },
        },
      };
    });

    connection.registerRequestHandler('session.create', (params) async {
      if (params is Map<String, dynamic>) {
        lastSessionCreateParams = Map<String, dynamic>.from(params);
      }
      _sessionCounter++;
      final sessionId = 'fake-session-$_sessionCounter';
      sessions[sessionId] = FakeSession(sessionId: sessionId);
      return {'sessionId': sessionId};
    });

    connection.registerRequestHandler('session.resume', (params) async {
      final p = params as Map<String, dynamic>;
      final sessionId = p['sessionId'] as String;
      if (!sessions.containsKey(sessionId)) {
        throw const JsonRpcError(code: -32600, message: 'Session not found');
      }
      return {'sessionId': sessionId};
    });

    connection.registerRequestHandler('session.destroy', (params) async {
      final p = params as Map<String, dynamic>;
      sessions.remove(p['sessionId'] as String);
      return <String, dynamic>{};
    });

    connection.registerRequestHandler('session.list', (params) async {
      return {
        'sessions': sessions.values.map((s) {
          return {
            'sessionId': s.sessionId,
            'startTime': '2025-01-01T00:00:00Z',
            'modifiedTime': '2025-01-01T01:00:00Z',
            'summary': 'Fake session ${s.sessionId}',
            'isRemote': false,
          };
        }).toList(),
      };
    });

    connection.registerRequestHandler('session.delete', (params) async {
      final p = params as Map<String, dynamic>;
      sessions.remove(p['sessionId'] as String);
      return <String, dynamic>{};
    });

    connection.registerRequestHandler('session.send', (params) async {
      return {'messageId': 'msg-1'};
    });

    connection.registerRequestHandler('session.getMessages', (params) async {
      return {'events': <Map<String, dynamic>>[]};
    });

    connection.registerRequestHandler('session.abort', (params) async {
      return <String, dynamic>{};
    });

    connection.registerRequestHandler(
      'session.model.getCurrent',
      (params) async => {'modelId': 'gpt-4'},
    );

    connection.registerRequestHandler(
      'session.model.switchTo',
      (params) async => <String, dynamic>{},
    );

    connection.registerRequestHandler(
      'session.mode.get',
      (params) async => {'mode': 'interactive'},
    );

    connection.registerRequestHandler(
      'session.mode.set',
      (params) async => <String, dynamic>{},
    );

    connection.registerRequestHandler(
      'session.plan.read',
      (params) async => {'plan': '# My Plan\n- Step 1\n- Step 2'},
    );

    connection.registerRequestHandler(
      'session.plan.update',
      (params) async => <String, dynamic>{},
    );

    connection.registerRequestHandler(
      'session.plan.delete',
      (params) async => <String, dynamic>{},
    );

    connection.registerRequestHandler(
      'session.workspace.listFiles',
      (params) async => {
        'files': ['main.dart', 'README.md'],
      },
    );

    connection.registerRequestHandler(
      'session.workspace.readFile',
      (params) async => {'content': 'void main() {}'},
    );

    connection.registerRequestHandler(
      'session.workspace.createFile',
      (params) async => <String, dynamic>{},
    );

    connection.registerRequestHandler(
      'session.fleet.start',
      (params) async => <String, dynamic>{},
    );
  }

  /// Sends a session event notification to the client.
  Future<void> sendSessionEvent(Map<String, dynamic> event) async {
    await connection.sendNotification('session.event', event);
  }

  /// Sends a tool call request to the client and returns the result.
  Future<Map<String, dynamic>> sendToolCallRequest({
    required String sessionId,
    required String toolName,
    required String toolCallId,
    Map<String, dynamic> arguments = const {},
  }) async {
    final result = await connection.sendRequest('toolCall.request', {
      'sessionId': sessionId,
      'toolName': toolName,
      'toolCallId': toolCallId,
      'arguments': arguments,
    });
    return result as Map<String, dynamic>;
  }

  /// Sends a permission request to the client.
  Future<Map<String, dynamic>> sendPermissionRequest({
    required String sessionId,
    Map<String, dynamic> data = const {},
  }) async {
    final result = await connection.sendRequest('permission.request', {
      'sessionId': sessionId,
      ...data,
    });
    return result as Map<String, dynamic>;
  }

  /// Sends a user input request to the client.
  Future<Map<String, dynamic>> sendUserInputRequest({
    required String sessionId,
    required String question,
    List<String>? choices,
    bool? allowFreeform,
  }) async {
    final result = await connection.sendRequest('userInput.request', {
      'sessionId': sessionId,
      'question': question,
      if (choices != null) 'choices': choices,
      if (allowFreeform != null) 'allowFreeform': allowFreeform,
    });
    return result as Map<String, dynamic>;
  }

  /// Sends a hooks.invoke request to the client.
  Future<Map<String, dynamic>> sendHookInvoke({
    required String sessionId,
    required String hookType,
    Map<String, dynamic> input = const {},
  }) async {
    final result = await connection.sendRequest('hooks.invoke', {
      'sessionId': sessionId,
      'hookType': hookType,
      'input': input,
    });
    return result as Map<String, dynamic>;
  }

  /// Override a specific RPC handler.
  void overrideHandler(
    String method,
    Future<dynamic> Function(dynamic params) handler,
  ) {
    connection.removeRequestHandler(method);
    connection.registerRequestHandler(method, handler);
  }

  Future<void> close() async {
    await connection.close();
    await pair.close();
  }
}

/// A fake session on the server side.
class FakeSession {
  FakeSession({required this.sessionId});

  final String sessionId;
}
