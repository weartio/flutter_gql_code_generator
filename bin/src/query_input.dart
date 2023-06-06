import 'package:gql/ast.dart' as gql;
import 'default_value.dart';

class QueryInput {
  QueryInput({
    required this.name,
    required this.type,
    this.defaultValue,
    this.directives = const [],
  });
  final String name;
  final gql.TypeNode type;
  final DefaultValue? defaultValue;
  final List<gql.DirectiveNode> directives;
}
