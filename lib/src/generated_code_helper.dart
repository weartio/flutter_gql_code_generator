String get generatedCodeHelper {
  return r'''
extension MapParserHelper on Map<String, dynamic> {
  T? tryParse<T>(String name, T? Function(dynamic) parser) {
    final dynamic value = this[name];
    if (value == null) {
      return null;
    }
    return parser(value);
  }
}

String tryParseString(dynamic value) {
  if (value is String) {
    return value;
  }
  return '$value';
}

int? tryParseInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  return int.tryParse(tryParseString(value));
}

double? tryParseFloat(dynamic value) {
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    return value;
  }
  if (value is String) {
    return double.tryParse(value);
  }
  if (value is bool) {
    return value ? 1 : 0;
  }
  return double.tryParse(tryParseString(value));
}

bool? tryParseBoolean(dynamic value) {
  if (value is bool) {
    return value;
  }
  if (value is int) {
    return value != 0;
  }
  if (value is String) {
    final v = int.tryParse(value);
    if (v != null) {
      return v != 0;
    }
  }
  return ['true', 'on', '1'].contains('$value'.toLowerCase());
}

List<T?>? Function(dynamic) arrayParser<T>(T? Function(dynamic) itemParser) {
  return (dynamic item) =>
      safeCast<List<dynamic>>(item)?.map(itemParser).toList();
}

T? safeCast<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

abstract class BaseRequest<TResult> {
  String get operation;
  String get operationName;
  Map<String, dynamic> get inputs;
  TResult? parseResult(dynamic value);
}

extension BaseRequestResultParser<T> on BaseRequest<T> {
  GraphQLResponse<T>? parseResponse(dynamic value) {
    return GraphQLResponse.fromDynamic(
      value,
      resultName: operationName,
      dataParser: parseResult,
    );
  }
}

class GraphQLResponse<T> {
  GraphQLResponse({
    this.data,
    this.errors,
  });

  final T? data;
  final List<GraphQLError?>? errors;

  static GraphQLResponse<T>? fromDynamic<T>(
    dynamic value, {
    required String resultName,
    required T? Function(dynamic) dataParser,
  }) {
    return fromMap(
      safeCast<Map<String, dynamic>>(value),
      resultName: resultName,
      dataParser: dataParser,
    );
  }

  static GraphQLResponse<T>? fromMap<T>(
    Map<String, dynamic>? map, {
    required String resultName,
    required T? Function(dynamic) dataParser,
  }) {
    if (map == null) {
      return null;
    }
    final dataMap = safeCast<Map<String, dynamic>>(map['data']);

    return GraphQLResponse(
      data: dataMap?.tryParse(resultName, dataParser),
      errors: map.tryParse(
        'errors',
        arrayParser(
          GraphQLError.fromDynamic,
        ),
      ),
    );
  }

  void throwIfHasErrors() {
    final noneNullErrors =
        (errors ?? []).where((e) => e != null).map((e) => e!).toList();
    if (noneNullErrors.isNotEmpty) {
      final message = 'api error:\n' + //
          noneNullErrors //
              .map((e) => (e.message ?? '').trim())
              .where((e) => e.isNotEmpty) //
              .map((e) => '- $e') //
              .join('\n');
      throw GraphQLException(message, noneNullErrors);
    }
  }
}

class GraphQLException implements Exception {
  const GraphQLException(this.message, this.errors);
  final String message;
  final List<GraphQLError> errors;
}

class GraphQLError {
  GraphQLError({
    this.message,
    this.locations,
  });

  final String? message;
  final List<GraphQLErrorLocation?>? locations;
  static GraphQLError? fromDynamic(dynamic value) {
    return fromMap(safeCast<Map<String, dynamic>>(value));
  }

  static GraphQLError? fromMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    return GraphQLError(
      message: value.tryParse(
        'message',
        tryParseString,
      ),
      locations: value.tryParse(
        'locations',
        arrayParser(GraphQLErrorLocation.fromDynamic),
      ),
    );
  }
}

class GraphQLErrorLocation {
  GraphQLErrorLocation({this.line, this.column});

  final int? line;
  final int? column;
  static GraphQLErrorLocation? fromDynamic(dynamic value) {
    return fromMap(safeCast<Map<String, dynamic>>(value));
  }

  static GraphQLErrorLocation? fromMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    return GraphQLErrorLocation(
      line: value.tryParse('line', tryParseInt),
      column: value.tryParse('column', tryParseInt),
    );
  }
}

''';
}
