import 'package:gql/ast.dart' as gql;
import 'member_type.dart';

extension TypeNodeExtensions on gql.TypeNode {
  bool get isNullable => !isNonNull;
}

extension NodeExtension on gql.Node {
  bool get isEnumDefinition => this is gql.EnumTypeDefinitionNode;
  MemberType get memberType {
    final def = this;
    if (def is gql.EnumTypeDefinitionNode) {
      return MemberType.enumeration;
    } else if (def is gql.InputObjectTypeDefinitionNode) {
      return MemberType.inputModel;
    } else if (def is gql.OperationDefinitionNode) {
      switch (def.type) {
        case gql.OperationType.query:
          return MemberType.query;
        case gql.OperationType.mutation:
          return MemberType.mutation;
        case gql.OperationType.subscription:
          return MemberType.subscription;
      }
    } else if (def is gql.ObjectTypeDefinitionNode) {
      return MemberType.outputModel;
    } else if (def is gql.InterfaceTypeDefinitionNode) {
      return MemberType.interface;
    }
    throw Exception(
        'unsupported type: ${def.runtimeType} can not get memberType');
  }
}
