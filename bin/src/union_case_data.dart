import 'package:gql/ast.dart' as gql;

import 'generator.dart';
import 'member_type.dart';
import 'primitive_types.dart';

class UnionCaseData {
  UnionCaseData({
    required this.gqlTypeName,
    required this.typeName,
    required this.caseName,
    required this.fieldName,
    required this.varName,
    required this.parser,
    required this.serializer,
  });

  final String gqlTypeName;
  final String typeName;
  final String caseName;
  final String fieldName;
  final String varName;
  final String parser;
  final String serializer;
  static UnionCaseData from(gql.NamedTypeNode node, Generator inGen) {
    if (node.isPrimitiveTypeName) {
      throw Exception('union scalar types are not supported !');
    }
    final type = inGen.mapType(node, addNullCheck: false);
    final fixedName = inGen.fixName(node.name.value, MemberType.field);
    final parser = inGen.getTypeParser(node);
    final serlizer = inGen.serlizerTypeMapping(
      node,
      addNullChecks: false,
    );

    return UnionCaseData(
      gqlTypeName: node.name.value,
      caseName: '${fixedName}Type',
      fieldName: '${fixedName}Value',
      typeName: type,
      varName: '${fixedName}Value',
      parser: parser,
      serializer: serlizer,
    );
  }
}
