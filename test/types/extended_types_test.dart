import 'package:copilot_sdk_dart/src/types/auth_types.dart';
import 'package:copilot_sdk_dart/src/types/client_options.dart';
import 'package:copilot_sdk_dart/src/types/connection_state.dart';
import 'package:copilot_sdk_dart/src/types/session_config.dart';
import 'package:copilot_sdk_dart/src/types/tool_types.dart';
import 'package:test/test.dart';

/// Extended type tests for comprehensive coverage of all serialization types.
void main() {
  // ── McpServerConfig ───────────────────────────────────────────────────

  group('McpServerConfig', () {
    test('toJson with all fields', () {
      const config = McpServerConfig(
        name: 'my-mcp',
        command: 'npx',
        args: ['-y', '@modelcontextprotocol/server-filesystem'],
        env: {'HOME': '/home/user'},
      );

      final json = config.toJson();

      expect(json['name'], 'my-mcp');
      expect(json['command'], 'npx');
      expect(json['args'], ['-y', '@modelcontextprotocol/server-filesystem']);
      expect(json['env'], {'HOME': '/home/user'});
    });

    test('toJson with minimal fields', () {
      const config = McpServerConfig(name: 'test', command: 'node');

      final json = config.toJson();

      expect(json['name'], 'test');
      expect(json['command'], 'node');
      expect(json.containsKey('args'), isFalse); // empty list omitted
      expect(json.containsKey('env'), isFalse);
    });

    test('toJson omits empty args', () {
      const config = McpServerConfig(name: 'test', command: 'node', args: []);

      expect(config.toJson().containsKey('args'), isFalse);
    });
  });

  // ── CustomAgentConfig ─────────────────────────────────────────────────

  group('CustomAgentConfig', () {
    test('toJson with all fields', () {
      const config = CustomAgentConfig(
        name: 'reviewer',
        description: 'Reviews code changes',
        instructions: 'Be thorough and constructive',
        tools: ['bash', 'read_file'],
      );

      final json = config.toJson();

      expect(json['name'], 'reviewer');
      expect(json['description'], 'Reviews code changes');
      expect(json['instructions'], 'Be thorough and constructive');
      expect(json['tools'], ['bash', 'read_file']);
    });

    test('toJson with name only', () {
      const config = CustomAgentConfig(name: 'minimal');

      final json = config.toJson();

      expect(json['name'], 'minimal');
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('instructions'), isFalse);
      expect(json.containsKey('tools'), isFalse);
    });
  });

  // ── ProviderConfig ────────────────────────────────────────────────────

  group('ProviderConfig', () {
    test('toJson with all fields', () {
      const config = ProviderConfig(
        type: 'openai',
        apiKey: 'sk-test-key',
        baseUrl: 'https://api.openai.com/v1',
      );

      final json = config.toJson();

      expect(json['type'], 'openai');
      expect(json['apiKey'], 'sk-test-key');
      expect(json['baseUrl'], 'https://api.openai.com/v1');
    });

    test('toJson without baseUrl', () {
      const config = ProviderConfig(type: 'azure', apiKey: 'key-123');

      final json = config.toJson();

      expect(json['type'], 'azure');
      expect(json['apiKey'], 'key-123');
      expect(json.containsKey('baseUrl'), isFalse);
    });
  });

  // ── SessionConfig ─────────────────────────────────────────────────────

  group('SessionConfig', () {
    test('toJson with all fields populated', () {
      final config = SessionConfig(
        model: 'gpt-4',
        systemMessage: const SystemMessageReplace(content: 'You are helpful.'),
        infiniteSessions: true,
        streaming: false,
        tools: [
          Tool(
            name: 'echo',
            description: 'Echo input',
            parameters: {
              'type': 'object',
              'properties': {
                'text': {'type': 'string'},
              },
            },
            handler: (a, i) async => ToolResult.success('ok'),
          ),
        ],
        availableTools: ['bash'],
        excludedTools: ['dangerous_tool'],
        mcpServers: [
          const McpServerConfig(name: 'fs', command: 'mcp-fs'),
        ],
        customAgents: [
          const CustomAgentConfig(name: 'agent1'),
        ],
        skillDirectories: ['/skills'],
        provider: const ProviderConfig(type: 'openai', apiKey: 'key'),
        reasoningEffort: ReasoningEffort.high,
        mode: AgentMode.autopilot,
        attachments: [Attachment.file('/tmp/test.txt')],
        onPermissionRequest: approveAllPermissions,
      );

      final json = config.toJson();

      expect(json['model'], 'gpt-4');
      expect(json['systemMessage'],
          {'mode': 'replace', 'content': 'You are helpful.'});
      expect(json['infiniteSessions'], isTrue);
      expect(json['streaming'], isFalse);
      expect((json['tools'] as List).length, 1);
      expect(json['availableTools'], ['bash']);
      expect(json['excludedTools'], ['dangerous_tool']);
      expect((json['mcpServers'] as List).length, 1);
      expect((json['customAgents'] as List).length, 1);
      expect(json['skillDirectories'], ['/skills']);
      expect(json['provider'], isNotNull);
      expect(json['reasoningEffort'], 'high');
      expect(json['mode'], 'autopilot');
      expect((json['attachments'] as List).length, 1);
    });

    test('toJson with minimal config', () {
      final config = SessionConfig(
        onPermissionRequest: approveAllPermissions,
      );

      final json = config.toJson();

      expect(json['streaming'], isTrue);
      expect(json.containsKey('model'), isFalse);
      expect(json.containsKey('systemMessage'), isFalse);
      expect(json.containsKey('tools'), isFalse); // empty tools omitted
    });
  });

  // ── ResumeSessionConfig ───────────────────────────────────────────────

  group('ResumeSessionConfig', () {
    test('holds all properties', () {
      final config = ResumeSessionConfig(
        sessionId: 'session-123',
        onPermissionRequest: approveAllPermissions,
        onUserInputRequest: (req, inv) async =>
            const UserInputResponse(answer: 'yes'),
        tools: [
          Tool(
            name: 'test',
            handler: (a, i) async => ToolResult.success('ok'),
          ),
        ],
      );

      expect(config.sessionId, 'session-123');
      expect(config.tools, hasLength(1));
      expect(config.onUserInputRequest, isNotNull);
    });
  });

  // ── MessageOptions ────────────────────────────────────────────────────

  group('MessageOptions', () {
    test('toJson with all fields', () {
      final options = MessageOptions(
        prompt: 'Hello',
        attachments: [Attachment.file('/tmp/image.png')],
        mode: AgentMode.plan,
      );

      final json = options.toJson();

      expect(json['prompt'], 'Hello');
      expect((json['attachments'] as List).length, 1);
      expect(json['mode'], 'plan');
    });

    test('toJson with prompt only', () {
      const options = MessageOptions(prompt: 'Just text');

      final json = options.toJson();

      expect(json['prompt'], 'Just text');
      expect(json.containsKey('attachments'), isFalse);
      expect(json.containsKey('mode'), isFalse);
    });
  });

  // ── SystemMessage ─────────────────────────────────────────────────────

  group('SystemMessage', () {
    test('SystemMessageAppend with content', () {
      const msg = SystemMessageAppend(content: 'Extra context');

      expect(msg.toJson(), {'mode': 'append', 'content': 'Extra context'});
    });

    test('SystemMessageAppend without content', () {
      const msg = SystemMessageAppend();

      expect(msg.toJson(), {'mode': 'append'});
    });

    test('SystemMessageReplace', () {
      const msg = SystemMessageReplace(content: 'Custom system prompt');

      expect(msg.toJson(), {
        'mode': 'replace',
        'content': 'Custom system prompt',
      });
    });
  });

  // ── UserInputRequest / UserInputResponse ──────────────────────────────

  group('UserInputRequest', () {
    test('fromJson with all fields', () {
      final req = UserInputRequest.fromJson({
        'question': 'Choose a database',
        'choices': ['PostgreSQL', 'MySQL', 'SQLite'],
        'allowFreeform': true,
      });

      expect(req.question, 'Choose a database');
      expect(req.choices, ['PostgreSQL', 'MySQL', 'SQLite']);
      expect(req.allowFreeform, isTrue);
    });

    test('fromJson with question only', () {
      final req = UserInputRequest.fromJson({
        'question': 'What is your name?',
      });

      expect(req.question, 'What is your name?');
      expect(req.choices, isNull);
      expect(req.allowFreeform, isNull);
    });
  });

  group('UserInputResponse', () {
    test('toJson with freeform', () {
      const resp =
          UserInputResponse(answer: 'Custom answer', wasFreeform: true);

      expect(resp.toJson(), {
        'answer': 'Custom answer',
        'wasFreeform': true,
      });
    });

    test('toJson defaults wasFreeform to false', () {
      const resp = UserInputResponse(answer: 'PostgreSQL');

      expect(resp.toJson(), {
        'answer': 'PostgreSQL',
        'wasFreeform': false,
      });
    });
  });

  // ── PermissionRequest / PermissionResult ──────────────────────────────

  group('PermissionRequest', () {
    test('fromJson preserves data', () {
      final req = PermissionRequest.fromJson({
        'sessionId': 's-1',
        'toolName': 'bash',
        'command': 'rm -rf /',
      });

      expect(req.data, isNotNull);
    });
  });

  group('PermissionResult', () {
    test('approved has correct kind', () {
      expect(PermissionResult.approved.kind, 'approved');
      expect(PermissionResult.approved.toJson(), {'kind': 'approved'});
    });

    test('denied has correct kind', () {
      expect(PermissionResult.denied.kind,
          'denied-no-approval-rule-and-could-not-request-from-user');
    });

    test('custom kind works', () {
      const result = PermissionResult(kind: 'custom-kind');

      expect(result.toJson(), {'kind': 'custom-kind'});
    });
  });

  // ── AgentMode ─────────────────────────────────────────────────────────

  group('AgentMode', () {
    test('toJsonValue returns name', () {
      expect(AgentMode.interactive.toJsonValue(), 'interactive');
      expect(AgentMode.plan.toJsonValue(), 'plan');
      expect(AgentMode.autopilot.toJsonValue(), 'autopilot');
    });

    test('fromJson parses known values', () {
      expect(AgentMode.fromJson('interactive'), AgentMode.interactive);
      expect(AgentMode.fromJson('plan'), AgentMode.plan);
      expect(AgentMode.fromJson('autopilot'), AgentMode.autopilot);
    });

    test('fromJson defaults to interactive for unknown', () {
      expect(AgentMode.fromJson('unknown'), AgentMode.interactive);
    });
  });

  // ── ReasoningEffort ───────────────────────────────────────────────────

  group('ReasoningEffort', () {
    test('toJsonValue returns name', () {
      expect(ReasoningEffort.low.toJsonValue(), 'low');
      expect(ReasoningEffort.medium.toJsonValue(), 'medium');
      expect(ReasoningEffort.high.toJsonValue(), 'high');
    });
  });

  // ── Attachment ────────────────────────────────────────────────────────

  group('Attachment', () {
    test('file factory', () {
      final att = Attachment.file('/tmp/test.txt');

      expect(att.type, 'file');
      expect(att.path, '/tmp/test.txt');
      expect(att.toJson(), {'type': 'file', 'path': '/tmp/test.txt'});
    });

    test('image factory', () {
      final att = Attachment.image(
        data: 'base64data==',
        mimeType: 'image/png',
      );

      expect(att.type, 'image');
      expect(att.data, 'base64data==');
      expect(att.mimeType, 'image/png');
    });

    test('toJson omits null fields', () {
      final att = Attachment.file('/test');
      final json = att.toJson();

      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('data'), isFalse);
      expect(json.containsKey('mimeType'), isFalse);
    });

    test('full constructor with all fields', () {
      const att = Attachment(
        type: 'url',
        url: 'https://example.com/file.txt',
        mimeType: 'text/plain',
      );

      final json = att.toJson();
      expect(json['type'], 'url');
      expect(json['url'], 'https://example.com/file.txt');
      expect(json['mimeType'], 'text/plain');
    });
  });

  // ── GetStatusResponse ─────────────────────────────────────────────────

  group('GetStatusResponse', () {
    test('fromJson parses correctly', () {
      final resp = GetStatusResponse.fromJson({
        'version': '2.0.0',
        'protocolVersion': 2,
      });

      expect(resp.version, '2.0.0');
      expect(resp.protocolVersion, 2);
    });
  });

  // ── GetAuthStatusResponse ─────────────────────────────────────────────

  group('GetAuthStatusResponse', () {
    test('fromJson with all fields', () {
      final resp = GetAuthStatusResponse.fromJson({
        'isAuthenticated': true,
        'authType': 'oauth',
        'host': 'github.com',
        'login': 'user1',
        'statusMessage': 'Authenticated successfully',
      });

      expect(resp.isAuthenticated, isTrue);
      expect(resp.authType, 'oauth');
      expect(resp.host, 'github.com');
      expect(resp.login, 'user1');
      expect(resp.statusMessage, 'Authenticated successfully');
    });

    test('fromJson with minimal fields', () {
      final resp = GetAuthStatusResponse.fromJson({
        'isAuthenticated': false,
      });

      expect(resp.isAuthenticated, isFalse);
      expect(resp.authType, isNull);
      expect(resp.host, isNull);
      expect(resp.login, isNull);
      expect(resp.statusMessage, isNull);
    });
  });

  // ── ModelInfo ──────────────────────────────────────────────────────────

  group('ModelInfo', () {
    test('fromJson with all fields', () {
      final info = ModelInfo.fromJson({
        'id': 'gpt-4o',
        'name': 'GPT-4o',
        'capabilities': {
          'supports': {'vision': true, 'reasoningEffort': true},
          'limits': {
            'max_context_window_tokens': 128000,
            'max_prompt_tokens': 64000,
          },
        },
        'policy': {'state': 'accepted', 'terms': 'MIT'},
        'billing': {'multiplier': 1.5},
        'supportedReasoningEfforts': ['low', 'medium', 'high'],
        'defaultReasoningEffort': 'medium',
      });

      expect(info.id, 'gpt-4o');
      expect(info.name, 'GPT-4o');
      expect(info.capabilities.supportsVision, isTrue);
      expect(info.capabilities.supportsReasoningEffort, isTrue);
      expect(info.capabilities.maxContextWindowTokens, 128000);
      expect(info.capabilities.maxPromptTokens, 64000);
      expect(info.policy!.state, 'accepted');
      expect(info.policy!.terms, 'MIT');
      expect(info.billing!.multiplier, 1.5);
      expect(info.supportedReasoningEfforts, ['low', 'medium', 'high']);
      expect(info.defaultReasoningEffort, 'medium');
    });

    test('fromJson with minimal fields', () {
      final info = ModelInfo.fromJson({
        'id': 'mini',
        'name': 'Mini',
        'capabilities': {
          'supports': {'vision': false, 'reasoningEffort': false},
          'limits': {'max_context_window_tokens': 8000},
        },
      });

      expect(info.policy, isNull);
      expect(info.billing, isNull);
      expect(info.supportedReasoningEfforts, isNull);
      expect(info.defaultReasoningEffort, isNull);
      expect(info.capabilities.maxPromptTokens, isNull);
    });
  });

  // ── ModelPolicy ───────────────────────────────────────────────────────

  group('ModelPolicy', () {
    test('fromJson parses correctly', () {
      final policy = ModelPolicy.fromJson({
        'state': 'accepted',
        'terms': 'https://example.com/terms',
      });

      expect(policy.state, 'accepted');
      expect(policy.terms, 'https://example.com/terms');
    });
  });

  // ── ModelBilling ──────────────────────────────────────────────────────

  group('ModelBilling', () {
    test('fromJson with double', () {
      final billing = ModelBilling.fromJson({'multiplier': 2.5});

      expect(billing.multiplier, 2.5);
    });

    test('fromJson with int', () {
      final billing = ModelBilling.fromJson({'multiplier': 1});

      expect(billing.multiplier, 1.0);
    });
  });

  // ── AccountQuota ──────────────────────────────────────────────────────

  group('AccountQuota', () {
    test('fromJson with multiple snapshots', () {
      final quota = AccountQuota.fromJson({
        'quotaSnapshots': {
          'copilot': {
            'entitlementRequests': 1000,
            'usedRequests': 250,
            'remainingPercentage': 75.0,
            'overage': 0,
            'overageAllowedWithExhaustedQuota': false,
          },
          'premium': {
            'entitlementRequests': 100,
            'usedRequests': 99,
            'remainingPercentage': 1.0,
            'overage': 0,
            'overageAllowedWithExhaustedQuota': true,
            'resetDate': '2025-07-01T00:00:00Z',
          },
        },
      });

      expect(quota.quotaSnapshots.length, 2);
      expect(quota.quotaSnapshots['copilot']!.entitlementRequests, 1000);
      expect(
          quota.quotaSnapshots['premium']!.resetDate, '2025-07-01T00:00:00Z');
      expect(quota.quotaSnapshots['premium']!.overageAllowedWithExhaustedQuota,
          isTrue);
    });
  });

  // ── QuotaSnapshot ─────────────────────────────────────────────────────

  group('QuotaSnapshot', () {
    test('fromJson with all fields', () {
      final snapshot = QuotaSnapshot.fromJson({
        'entitlementRequests': 500,
        'usedRequests': 123,
        'remainingPercentage': 75.4,
        'overage': 0,
        'overageAllowedWithExhaustedQuota': false,
        'resetDate': '2025-06-01T00:00:00Z',
      });

      expect(snapshot.entitlementRequests, 500);
      expect(snapshot.usedRequests, 123);
      expect(snapshot.remainingPercentage, 75.4);
      expect(snapshot.overage, 0);
      expect(snapshot.overageAllowedWithExhaustedQuota, isFalse);
      expect(snapshot.resetDate, '2025-06-01T00:00:00Z');
    });

    test('fromJson without resetDate', () {
      final snapshot = QuotaSnapshot.fromJson({
        'entitlementRequests': 100,
        'usedRequests': 50,
        'remainingPercentage': 50.0,
        'overage': 0,
        'overageAllowedWithExhaustedQuota': false,
      });

      expect(snapshot.resetDate, isNull);
    });
  });

  // ── ToolInfo ──────────────────────────────────────────────────────────

  group('ToolInfo', () {
    test('fromJson with all fields', () {
      final info = ToolInfo.fromJson({
        'name': 'bash',
        'description': 'Run bash commands',
        'namespacedName': 'copilot.bash',
        'parameters': {
          'type': 'object',
          'properties': {
            'command': {'type': 'string'},
          },
        },
        'instructions': 'Use bash for shell operations.',
      });

      expect(info.name, 'bash');
      expect(info.description, 'Run bash commands');
      expect(info.namespacedName, 'copilot.bash');
      expect(info.parameters, isNotNull);
      expect(info.instructions, 'Use bash for shell operations.');
    });

    test('fromJson with minimal fields', () {
      final info = ToolInfo.fromJson({
        'name': 'test',
        'description': 'A test tool',
      });

      expect(info.namespacedName, isNull);
      expect(info.parameters, isNull);
      expect(info.instructions, isNull);
    });
  });

  // ── SessionMetadata ───────────────────────────────────────────────────

  group('SessionMetadata', () {
    test('fromJson with all fields', () {
      final meta = SessionMetadata.fromJson({
        'sessionId': 's-42',
        'startTime': '2025-01-15T10:00:00Z',
        'modifiedTime': '2025-01-15T11:00:00Z',
        'summary': 'Implemented auth module',
        'isRemote': true,
        'context': {
          'cwd': '/home/user/project',
          'gitRoot': '/home/user/project',
          'repository': 'user/project',
          'branch': 'main',
        },
      });

      expect(meta.sessionId, 's-42');
      expect(meta.startTime.year, 2025);
      expect(meta.modifiedTime.month, 1);
      expect(meta.summary, 'Implemented auth module');
      expect(meta.isRemote, isTrue);
      expect(meta.context, isNotNull);
      expect(meta.context!.cwd, '/home/user/project');
      expect(meta.context!.repository, 'user/project');
      expect(meta.context!.branch, 'main');
    });

    test('fromJson with minimal fields', () {
      final meta = SessionMetadata.fromJson({
        'sessionId': 's-1',
        'startTime': '2025-01-01T00:00:00Z',
        'modifiedTime': '2025-01-01T00:00:00Z',
      });

      expect(meta.summary, isNull);
      expect(meta.isRemote, isFalse);
      expect(meta.context, isNull);
    });
  });

  // ── SessionContext ────────────────────────────────────────────────────

  group('SessionContext', () {
    test('fromJson and toJson round-trip', () {
      final original = {
        'cwd': '/tmp/test',
        'gitRoot': '/tmp/test',
        'repository': 'owner/repo',
        'branch': 'feature-x',
      };

      final ctx = SessionContext.fromJson(original);
      final json = ctx.toJson();

      expect(json['cwd'], '/tmp/test');
      expect(json['gitRoot'], '/tmp/test');
      expect(json['repository'], 'owner/repo');
      expect(json['branch'], 'feature-x');
    });

    test('toJson omits null fields', () {
      const ctx = SessionContext(cwd: '/tmp');
      final json = ctx.toJson();

      expect(json['cwd'], '/tmp');
      expect(json.containsKey('gitRoot'), isFalse);
      expect(json.containsKey('repository'), isFalse);
      expect(json.containsKey('branch'), isFalse);
    });
  });

  // ── SessionListFilter ─────────────────────────────────────────────────

  group('SessionListFilter', () {
    test('toJson with all fields', () {
      const filter = SessionListFilter(
        cwd: '/tmp',
        gitRoot: '/tmp',
        repository: 'owner/repo',
        branch: 'main',
      );

      final json = filter.toJson();

      expect(json['cwd'], '/tmp');
      expect(json['gitRoot'], '/tmp');
      expect(json['repository'], 'owner/repo');
      expect(json['branch'], 'main');
    });

    test('toJson omits null fields', () {
      const filter = SessionListFilter(repository: 'owner/repo');

      final json = filter.toJson();

      expect(json.keys, ['repository']);
    });

    test('toJson with no fields returns empty map', () {
      const filter = SessionListFilter();

      expect(filter.toJson(), isEmpty);
    });
  });

  // ── ForegroundSessionInfo ─────────────────────────────────────────────

  group('ForegroundSessionInfo', () {
    test('fromJson with all fields', () {
      final info = ForegroundSessionInfo.fromJson({
        'sessionId': 's-1',
        'workspacePath': '/home/user/project',
      });

      expect(info.sessionId, 's-1');
      expect(info.workspacePath, '/home/user/project');
    });

    test('fromJson with null fields', () {
      final info = ForegroundSessionInfo.fromJson({});

      expect(info.sessionId, isNull);
      expect(info.workspacePath, isNull);
    });
  });

  // ── ConnectionState ───────────────────────────────────────────────────

  group('ConnectionState', () {
    test('all values exist', () {
      expect(ConnectionState.values, hasLength(4));
      expect(
          ConnectionState.values,
          containsAll([
            ConnectionState.disconnected,
            ConnectionState.connecting,
            ConnectionState.connected,
            ConnectionState.error,
          ]));
    });
  });

  // ── CopilotClientOptions ──────────────────────────────────────────────

  group('CopilotClientOptions', () {
    test('default values', () {
      const options = CopilotClientOptions();

      expect(options.cliPath, isNull);
      expect(options.cliArgs, isEmpty);
      expect(options.port, 0);
      expect(options.useStdio, isTrue);
      expect(options.autoStart, isTrue);
      expect(options.autoRestart, isTrue);
    });

    test('custom values', () {
      const options = CopilotClientOptions(
        cliPath: '/usr/bin/copilot',
        cliArgs: ['--verbose'],
        cwd: '/tmp',
        port: 8080,
        useStdio: false,
        cliUrl: 'localhost:8080',
        logLevel: LogLevel.debug,
        autoStart: false,
        autoRestart: false,
        env: {'TOKEN': 'abc'},
        githubToken: 'ghp_test',
        useLoggedInUser: true,
      );

      expect(options.cliPath, '/usr/bin/copilot');
      expect(options.cliArgs, ['--verbose']);
      expect(options.cwd, '/tmp');
      expect(options.port, 8080);
      expect(options.useStdio, isFalse);
      expect(options.cliUrl, 'localhost:8080');
      expect(options.logLevel, LogLevel.debug);
      expect(options.autoStart, isFalse);
      expect(options.autoRestart, isFalse);
      expect(options.env, {'TOKEN': 'abc'});
      expect(options.githubToken, 'ghp_test');
      expect(options.useLoggedInUser, isTrue);
    });
  });

  // ── LogLevel ──────────────────────────────────────────────────────────

  group('LogLevel', () {
    test('toJsonValue returns name', () {
      expect(LogLevel.none.toJsonValue(), 'none');
      expect(LogLevel.error.toJsonValue(), 'error');
      expect(LogLevel.warning.toJsonValue(), 'warning');
      expect(LogLevel.info.toJsonValue(), 'info');
      expect(LogLevel.debug.toJsonValue(), 'debug');
      expect(LogLevel.all.toJsonValue(), 'all');
    });
  });

  // ── ToolResult subtypes ───────────────────────────────────────────────

  group('ToolResult subtypes', () {
    test('ToolResultObject toJson with all fields', () {
      const result = ToolResultObject(
        textResultForLlm: 'Analysis complete',
        resultType: ToolResultType.success,
        error: null,
        toolTelemetry: {'duration_ms': 250},
      );

      final json = result.toJson();

      expect(json['textResultForLlm'], 'Analysis complete');
      expect(json['resultType'], 'success');
      expect(json.containsKey('error'), isFalse);
      expect(json['toolTelemetry'], {'duration_ms': 250});
    });

    test('ToolResultObject toJson with error', () {
      const result = ToolResultObject(
        textResultForLlm: 'Failed',
        resultType: ToolResultType.failure,
        error: 'Timeout',
      );

      final json = result.toJson();

      expect(json['error'], 'Timeout');
      expect(json['resultType'], 'failure');
    });

    test('ToolResultType values', () {
      expect(ToolResultType.success.toJsonValue(), 'success');
      expect(ToolResultType.failure.toJsonValue(), 'failure');
      expect(ToolResultType.rejected.toJsonValue(), 'rejected');
      expect(ToolResultType.denied.toJsonValue(), 'denied');
    });

    test('ToolResultFailure default textForLlm', () {
      const result = ToolResultFailure(error: 'oops');
      final json = result.toJson();

      expect(json['textResultForLlm'], contains('error'));
      expect(json['error'], 'oops');
    });
  });

  // ── Tool registration ─────────────────────────────────────────────────

  group('Tool registration', () {
    test('toRegistrationJson excludes handler', () {
      final tool = Tool(
        name: 'greet',
        description: 'Greets a person',
        parameters: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
          'required': ['name'],
        },
        handler: (a, i) async => ToolResult.success('hello'),
      );

      final json = tool.toRegistrationJson();

      expect(json['name'], 'greet');
      expect(json['description'], 'Greets a person');
      expect(json['parameters'], isNotNull);
      expect(json.containsKey('handler'), isFalse);
    });

    test('toRegistrationJson with minimal fields', () {
      final tool = Tool(
        name: 'no-desc',
        handler: (a, i) async => ToolResult.success('ok'),
      );

      final json = tool.toRegistrationJson();

      expect(json['name'], 'no-desc');
      expect(json.containsKey('description'), isFalse);
      expect(json.containsKey('parameters'), isFalse);
    });
  });

  // ── normalizeToolResult ───────────────────────────────────────────────

  group('normalizeToolResult', () {
    test('null returns failure', () {
      final result = normalizeToolResult(null);

      expect(result, isA<ToolResultFailure>());
    });

    test('ToolResult passthrough', () {
      final original = ToolResult.success('hello');
      final result = normalizeToolResult(original);

      expect(identical(result, original), isTrue);
    });

    test('String becomes success', () {
      final result = normalizeToolResult('hello world');

      expect(result, isA<ToolResultSuccess>());
      expect((result as ToolResultSuccess).text, 'hello world');
    });

    test('other types become success via toString', () {
      final result = normalizeToolResult(42);

      expect(result, isA<ToolResultSuccess>());
      expect((result as ToolResultSuccess).text, '42');
    });
  });

  // ── ToolInvocation ────────────────────────────────────────────────────

  group('ToolInvocation', () {
    test('stores all fields', () {
      const inv = ToolInvocation(
        sessionId: 's-1',
        toolCallId: 'tc-1',
        toolName: 'bash',
        arguments: {'cmd': 'ls'},
      );

      expect(inv.sessionId, 's-1');
      expect(inv.toolCallId, 'tc-1');
      expect(inv.toolName, 'bash');
      expect(inv.arguments, {'cmd': 'ls'});
    });
  });

  // ── approveAllPermissions ─────────────────────────────────────────────

  group('approveAllPermissions', () {
    test('returns approved', () async {
      final result = await approveAllPermissions(
        const PermissionRequest(),
        const PermissionInvocation(sessionId: 's-1'),
      );

      expect(result.kind, 'approved');
    });
  });
}
