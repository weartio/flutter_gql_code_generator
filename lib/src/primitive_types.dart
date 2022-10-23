enum PrimitveTypes { ID, String, Int, Float, Boolean }

extension PrimitveTypesExtensions on PrimitveTypes {
  String get dartName {
    switch (this) {
      case PrimitveTypes.ID:
      case PrimitveTypes.String:
        return 'String';
      case PrimitveTypes.Int:
        return 'int';
      case PrimitveTypes.Float:
        return 'double';
      case PrimitveTypes.Boolean:
        return 'bool';
    }
  }

  String get parser {
    switch (this) {
      case PrimitveTypes.ID:
      case PrimitveTypes.String:
        return 'tryParseString';
      case PrimitveTypes.Int:
        return 'tryParseInt';
      case PrimitveTypes.Float:
        return 'tryParseFloat';
      case PrimitveTypes.Boolean:
        return 'tryParseBoolean';
    }
  }

  String get defaultValue {
    switch (this) {
      case PrimitveTypes.ID:
      case PrimitveTypes.String:
        return "''";
      case PrimitveTypes.Int:
      case PrimitveTypes.Float:
        return '0';
      case PrimitveTypes.Boolean:
        return 'false';
    }
  }
}
