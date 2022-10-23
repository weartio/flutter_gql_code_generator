import 'package:gql/ast.dart' as gql;
import 'generator.dart';
import 'member_type.dart';
import 'query_input.dart';
import 'type_info.dart';

class OperationInfo {
  OperationInfo(
    this.filePath,
    this.queryName,
    this.inputs,
    this.type,
  );
  final String filePath;
  final String queryName;
  final List<QueryInput> inputs;
  final gql.OperationType type;
  MemberType get memberType {
    switch (type) {
      case gql.OperationType.query:
        return MemberType.query;
      case gql.OperationType.mutation:
        return MemberType.mutation;
      case gql.OperationType.subscription:
        return MemberType.subscription;
    }
  }

  late TypeInfo outputType;

  void resolveOutput(Generator generator) {
    final operation = generator.findOperation(this);

    final operationType = operation.type;

    outputType = TypeInfo(
      type: operationType,
      isNoneNull: operation.type.isNonNull,
    );
  }
}
