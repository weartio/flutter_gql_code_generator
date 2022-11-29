import 'package:gql/ast.dart' as gql;
import 'generator.dart';
import 'member_type.dart';
import 'query_input.dart';
import 'type_info.dart';

class OperationInfo {
  OperationInfo(
    this.filePath,
    this.queryNames,
    this.inputs,
    this.type,
  );
  final String filePath;
  final List<String> queryNames;
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

  late Map<String, TypeInfo> outputTypes;

  void resolveOutput(Generator generator) {
    final operation = generator.findOperation(this);
    final result = <String, TypeInfo>{};
    for (final item in operation.entries) {
      final operationType = item.value.type;
      result[item.key] = TypeInfo(
        type: operationType,
        isNoneNull: item.value.type.isNonNull,
      );
    }
    outputTypes = result;
  }
}
