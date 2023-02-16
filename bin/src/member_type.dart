enum MemberType {
  inputModel,
  outputModel,
  enumeration,
  field,
  query,
  mutation,
  subscription,
  interface,
  union,
}

extension MemberTypeExtension on MemberType {
  String get subFolderName {
    switch (this) {
      case MemberType.inputModel:
        return 'InputModels';
      case MemberType.outputModel:
        return 'Models';
      case MemberType.enumeration:
        return 'Enums';
      case MemberType.field:
        throw Exception('fileds can not be written to files !!');
      case MemberType.query:
        return 'Queries';
      case MemberType.mutation:
        return 'Mutations';
      case MemberType.subscription:
        return 'Subscriptions';
      case MemberType.interface:
        return 'Interfaces';
      case MemberType.union:
        return 'Union';
    }
  }
}
