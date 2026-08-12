import 'package:json_ast/json_ast.dart' as json_ast;
import 'dart:convert';
import 'lib/parsers/jsonc_cleaner.dart';

class _Edit {
  final int start;
  final int end;
  final String replacement;
  _Edit(this.start, this.end, this.replacement);
}

void main() {
  final originalContent = '{ "a": 1, /* comment */ "rules": [1, 2, ], // tail\n "b": 2 }';
  final cleanContent = JsoncCleaner.clean(originalContent);
  final ast = json_ast.parse(cleanContent, json_ast.Settings());

  if (ast is json_ast.ObjectNode) {
    String result = originalContent;
    final edits = <_Edit>[];

    json_ast.PropertyNode? rulesNode;
    json_ast.PropertyNode? permissionsNode;
    for (final prop in ast.children) {
      if (prop.key!.value == 'rules') rulesNode = prop;
      if (prop.key!.value == 'permissions') permissionsNode = prop;
    }

    if (rulesNode != null) {
      edits.add(_Edit(rulesNode.value!.loc!.start.offset, rulesNode.value!.loc!.end.offset, '["new"]'));
    }

    if (permissionsNode == null) {
      final insertPos = ast.loc!.end.offset - 1;
      final insertion = ',\n  "permissions": ["perm"]\n';
      result = result.replaceRange(insertPos, insertPos, insertion);
    }

    edits.sort((a, b) => b.start.compareTo(a.start));
    for (final edit in edits) {
      result = result.replaceRange(edit.start, edit.end, edit.replacement);
    }

    print('Result:');
    print(result);
  }
}
