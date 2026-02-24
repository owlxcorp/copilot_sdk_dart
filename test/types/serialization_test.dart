import 'package:copilot_sdk_dart/src/types/auth_types.dart';
import 'package:copilot_sdk_dart/src/types/session_config.dart';
import 'package:test/test.dart';

void main() {
  group('SessionConfig.toJson', () {
    test('minimal config produces correct JSON', () {
      final config = SessionConfig(
        onPermissionRequest: approveAllPermissions,
      );

      final json = config.toJson();
      expect(json['streaming'], true);
      expect(json.containsKey('model'), false);
      expect(json.containsKey('tools'), false);
    });

    test('full config includes all fields', () {
      final config = SessionConfig(
        model: 'gpt-4',
        streaming: true,
        reasoningEffort: ReasoningEffort.high,
        mode: AgentMode.autopilot,
        onPermissionRequest: approveAllPermissions,
      );

      final json = config.toJson();
      expect(json['model'], 'gpt-4');
      expect(json['streaming'], true);
      expect(json['reasoningEffort'], 'high');
      expect(json['mode'], 'autopilot');
    });
  });

  group('SystemMessageConfig', () {
    test('append mode serializes correctly', () {
      final config = SystemMessageAppend(content: 'Be concise.');
      final json = config.toJson();
      expect(json['mode'], 'append');
      expect(json['content'], 'Be concise.');
    });

    test('replace mode serializes correctly', () {
      final config = SystemMessageReplace(content: 'You are a bot.');
      final json = config.toJson();
      expect(json['mode'], 'replace');
      expect(json['content'], 'You are a bot.');
    });
  });

  group('Attachment', () {
    test('file attachment', () {
      final a = Attachment.file('/path/to/file.txt');
      final json = a.toJson();
      expect(json['type'], 'file');
      expect(json['path'], '/path/to/file.txt');
    });

    test('image attachment', () {
      final a = Attachment.image(data: 'base64data', mimeType: 'image/png');
      final json = a.toJson();
      expect(json['type'], 'image');
      expect(json['data'], 'base64data');
      expect(json['mimeType'], 'image/png');
    });
  });

  group('AgentMode', () {
    test('fromJson parses valid values', () {
      expect(AgentMode.fromJson('interactive'), AgentMode.interactive);
      expect(AgentMode.fromJson('plan'), AgentMode.plan);
      expect(AgentMode.fromJson('autopilot'), AgentMode.autopilot);
    });

    test('fromJson defaults to interactive for unknown', () {
      expect(AgentMode.fromJson('unknown'), AgentMode.interactive);
    });

    test('toJsonValue returns name', () {
      expect(AgentMode.autopilot.toJsonValue(), 'autopilot');
    });
  });

  group('PermissionResult', () {
    test('approved produces correct JSON', () {
      expect(PermissionResult.approved.toJson(), {'kind': 'approved'});
    });

    test('denied produces correct JSON', () {
      final json = PermissionResult.denied.toJson();
      expect(json['kind'], contains('denied'));
    });
  });

  group('GetAuthStatusResponse', () {
    test('fromJson parses correctly', () {
      final json = {
        'isAuthenticated': true,
        'authType': 'oauth',
        'host': 'github.com',
        'login': 'octocat',
      };

      final response = GetAuthStatusResponse.fromJson(json);
      expect(response.isAuthenticated, true);
      expect(response.authType, 'oauth');
      expect(response.login, 'octocat');
    });
  });

  group('ModelInfo', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'gpt-4',
        'name': 'GPT-4',
        'capabilities': {
          'supports': {
            'vision': true,
            'reasoningEffort': true,
          },
          'limits': {
            'max_context_window_tokens': 128000,
          },
        },
      };

      final model = ModelInfo.fromJson(json);
      expect(model.id, 'gpt-4');
      expect(model.name, 'GPT-4');
      expect(model.capabilities.supportsVision, true);
      expect(model.capabilities.maxContextWindowTokens, 128000);
    });
  });

  group('SessionMetadata', () {
    test('fromJson parses correctly', () {
      final json = {
        'sessionId': 'sess-123',
        'startTime': '2025-01-01T00:00:00Z',
        'modifiedTime': '2025-01-01T01:00:00Z',
        'summary': 'Test session',
        'isRemote': false,
        'context': {
          'cwd': '/home/user/project',
          'gitRoot': '/home/user/project',
          'repository': 'owner/repo',
          'branch': 'main',
        },
      };

      final meta = SessionMetadata.fromJson(json);
      expect(meta.sessionId, 'sess-123');
      expect(meta.summary, 'Test session');
      expect(meta.context?.cwd, '/home/user/project');
      expect(meta.context?.branch, 'main');
    });
  });

  group('approveAllPermissions', () {
    test('returns approved', () async {
      final result = await approveAllPermissions(
        const PermissionRequest(),
        const PermissionInvocation(sessionId: 'test'),
      );
      expect(result, PermissionResult.approved);
    });
  });
}
