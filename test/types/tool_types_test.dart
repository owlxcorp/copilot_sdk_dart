import 'package:copilot_sdk_dart/src/types/tool_types.dart';
import 'package:test/test.dart';

void main() {
  group('Tool', () {
    test('toRegistrationJson excludes handler', () {
      final tool = Tool(
        name: 'weather',
        description: 'Get weather',
        parameters: {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
        },
        handler: (args, inv) async => ToolResult.success('Sunny'),
      );

      final json = tool.toRegistrationJson();
      expect(json['name'], 'weather');
      expect(json['description'], 'Get weather');
      expect(json['parameters'], isNotNull);
      expect(json.containsKey('handler'), false);
    });
  });

  group('ToolResult', () {
    test('success creates proper JSON', () {
      final result = ToolResult.success('It is sunny');
      final json = result.toJson();
      expect(json['textResultForLlm'], 'It is sunny');
      expect(json['resultType'], 'success');
    });

    test('failure creates proper JSON', () {
      final result = ToolResult.failure(error: 'Network error');
      final json = result.toJson();
      expect(json['error'], 'Network error');
      expect(json['resultType'], 'failure');
      expect(json['textResultForLlm'], isNotEmpty);
    });

    test('failure with custom text for LLM', () {
      final result = ToolResult.failure(
        error: 'API down',
        textForLlm: 'Weather service unavailable',
      );
      final json = result.toJson();
      expect(json['textResultForLlm'], 'Weather service unavailable');
    });

    test('object creates proper JSON', () {
      final result = ToolResult.object(
        textResultForLlm: 'Result data',
        resultType: ToolResultType.success,
        toolTelemetry: {'latencyMs': 150},
      );
      final json = result.toJson();
      expect(json['textResultForLlm'], 'Result data');
      expect(json['resultType'], 'success');
      expect(json['toolTelemetry'], {'latencyMs': 150});
    });
  });

  group('normalizeToolResult', () {
    test('null returns failure', () {
      final result = normalizeToolResult(null);
      expect(result, isA<ToolResultFailure>());
    });

    test('ToolResult passes through', () {
      final original = ToolResult.success('hello');
      final result = normalizeToolResult(original);
      expect(identical(result, original), true);
    });

    test('String becomes success', () {
      final result = normalizeToolResult('test output');
      expect(result, isA<ToolResultSuccess>());
      expect((result as ToolResultSuccess).text, 'test output');
    });

    test('other types use toString', () {
      final result = normalizeToolResult(42);
      expect(result, isA<ToolResultSuccess>());
      expect((result as ToolResultSuccess).text, '42');
    });
  });
}
