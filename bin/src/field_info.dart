import 'package:gql/ast.dart' as gql;
import 'default_value.dart';

class FieldInfo {
  FieldInfo({
    required this.name,
    this.aliase,
    required this.type,
    this.defaultValue,
  });
  final String name;
  final String? aliase;
  final gql.TypeNode type;
  final DefaultValue? defaultValue;

  String get codeGenName {
    if ((aliase ?? '').isNotEmpty) {
      return aliase ?? '';
    }
    return name;
  }
}
