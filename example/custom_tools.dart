/// Example: Register and handle custom tools.
///
/// Run with: dart run example/custom_tools.dart
library;

import 'dart:convert';
import 'dart:io';

import 'package:copilot_sdk_dart/copilot_sdk_io.dart';

Future<void> main() async {
  final transport = StdioTransport(
    executable: 'copilot',
    arguments: ['--headless', '--stdio', '--no-auto-update'],
  );
  await transport.start();

  final client = CopilotClient(
    options: const CopilotClientOptions(),
    transport: transport,
  );
  await client.start();

  // Define custom tools
  final weatherTool = Tool(
    name: 'get_weather',
    description: 'Get the current weather for a city',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {
          'type': 'string',
          'description': 'City name',
        },
      },
      'required': ['city'],
    },
    handler: (args, invocation) async {
      final city = (args as Map<String, dynamic>)['city'] as String;
      // In a real app, call a weather API
      final weather = {
        'city': city,
        'temperature': '72°F',
        'conditions': 'Sunny',
        'humidity': '45%',
      };
      return ToolResult.success(jsonEncode(weather));
    },
  );

  final calculatorTool = Tool(
    name: 'calculator',
    description: 'Evaluate a mathematical expression',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {
          'type': 'string',
          'description': 'Mathematical expression to evaluate',
        },
      },
      'required': ['expression'],
    },
    handler: (args, invocation) async {
      final expr = (args as Map<String, dynamic>)['expression'] as String;
      // Simple eval (in production, use a proper parser)
      return ToolResult.success('Result of $expr = [computed]');
    },
  );

  // Create session with tools
  final session = await client.createSession(
    config: SessionConfig(
      tools: [weatherTool, calculatorTool],
      onPermissionRequest: approveAllPermissions,
    ),
  );

  // Listen for tool execution events
  session.on((event) {
    switch (event) {
      case ToolExecutionStartEvent(:final toolName):
        print('🔧 Calling tool: $toolName');
      case ToolExecutionCompleteEvent(:final toolCallId, :final result):
        print('✅ Tool call $toolCallId returned: $result');
      case AssistantMessageEvent(:final content):
        stdout.write(content);
      case SessionIdleEvent():
        print('\n--- Done ---');
      default:
        break;
    }
  });

  // Ask something that will trigger tool use
  await session.sendAndWait(
    'What is the weather in Seattle? Also calculate 15 * 7.',
  );

  await session.destroy();
  await client.stop();
}
