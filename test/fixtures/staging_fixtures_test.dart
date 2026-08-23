import 'dart:io';

import 'package:agents_config_helper/models/discovery_request.dart';
import 'package:agents_config_helper/models/tool_config.dart';
import 'package:agents_config_helper/parsers/json_config_parser.dart';
import 'package:agents_config_helper/parsers/toml_config_parser.dart';
import 'package:agents_config_helper/parsers/yaml_config_parser.dart';
import 'package:agents_config_helper/services/discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  final fixtureRoot = p.join(
    Directory.current.path,
    'test',
    'fixtures',
    'staging_home',
  );

  String fixture(String relativePath) => p.join(fixtureRoot, relativePath);

  test(
    'staging fixture tree discovers representative user and project paths',
    () async {
      final result = await const DiscoveryService().discoverConfigs(
        DiscoveryRequest(
          normalizedHomePath: fixtureRoot,
          normalizedProjectRoots: [fixture('workspace')],
          enableClineRulesFallback: false,
        ),
      );

      expect(
        result.items.map((item) => item.filePath),
        containsAll([
          fixture('.claude/settings.json'),
          fixture('.claude/CLAUDE.md'),
          fixture('.codex/config.toml'),
          fixture('.config/opencode/opencode.json'),
          fixture('.kiro/settings/permissions.yaml'),
          fixture('.agents/AGENTS.md'),
          fixture('workspace/.claude/settings.json'),
          fixture('workspace/.codex/config.toml'),
          fixture('workspace/AGENTS.md'),
        ]),
      );
    },
  );

  test('edge-case fixtures remain parseable', () {
    final jsonConfig = JsonConfigParser().parse(
      File(
        p.join(
          Directory.current.path,
          'test',
          'fixtures',
          'edge_cases',
          'jsonc_with_comment.jsonc',
        ),
      ).readAsStringSync(),
      filePath: 'jsonc_with_comment.jsonc',
      toolName: 'Fixture',
      format: ConfigFormat.jsonc,
    );
    final yamlConfig = YamlConfigParser().parse(
      File(
        p.join(
          Directory.current.path,
          'test',
          'fixtures',
          'edge_cases',
          'yaml_multiline.yaml',
        ),
      ).readAsStringSync(),
      filePath: 'yaml_multiline.yaml',
      toolName: 'Fixture',
      format: ConfigFormat.yaml,
    );
    final tomlConfig = TomlConfigParser().parse(
      File(
        p.join(
          Directory.current.path,
          'test',
          'fixtures',
          'edge_cases',
          'toml_nested.toml',
        ),
      ).readAsStringSync(),
      filePath: 'toml_nested.toml',
      toolName: 'Fixture',
      format: ConfigFormat.toml,
    );

    expect(jsonConfig.rules, ['fixture rule']);
    expect(jsonConfig.parseWarnings, isNotEmpty);
    expect(yamlConfig.rules.single, contains('folded multiline rule'));
    expect(tomlConfig.rules, ['fixture rule']);
  });
}
