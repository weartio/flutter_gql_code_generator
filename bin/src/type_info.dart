import 'package:gql/ast.dart' as gql;

class TypeInfo {
  TypeInfo({required this.type, required this.isNoneNull});
  final gql.TypeNode type;
  final bool isNoneNull;
}
