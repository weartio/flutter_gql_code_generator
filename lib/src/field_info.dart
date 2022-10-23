import 'package:gql/ast.dart' as gql;
import 'default_value.dart';

class FieldInfo {
  FieldInfo({
    required this.name,
    required this.type,
    this.defaultValue,
  });
  final String name;
  final gql.TypeNode type;
  final DefaultValue? defaultValue;
}
