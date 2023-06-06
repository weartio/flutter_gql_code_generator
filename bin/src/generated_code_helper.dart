String get generatedCodeHelper {
  return r'''
import 'dart:convert';
import 'fragment_defs.dart';

var isDebugMode = false;

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


extension<T> on Iterable<T?> {
  List<T> noneNullList() =>
      where((e) => e != null).map((e) => e!).toList();
}

List<T>? Function(dynamic) arrayParserNoneNull<T>(
    T? Function(dynamic) itemParser) {
  return (dynamic item) =>
      safeCast<List<dynamic>>(item)?.map(itemParser).noneNullList();
}

T? safeCast<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

abstract class BaseRequest<TResult> {
  String get operation;
  List<String> get operationNames;
  Map<String, dynamic> get inputs;
  TResult? parseResult(dynamic value);
}

extension BaseRequestResultParser<T> on BaseRequest<T> {
  GraphQLResponse<T>? parseResponse(dynamic value) {
    return GraphQLResponse.fromDynamic(
      value,
      resultNames: operationNames,
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
    required List<String> resultNames,
    required T? Function(dynamic) dataParser,
  }) {
    if (value is String) {
      // parse json and try again using recursing
      return fromDynamic(
        jsonDecode(value),
        resultNames: resultNames,
        dataParser: dataParser,
      );
    } else if (value is Map<String, dynamic>) {
      return fromMap(
        value,
        resultNames: resultNames,
        dataParser: dataParser,
      );
    }
    // TODO(team): should we just throw an error & make the result none nullable
    return null;
  }

  static GraphQLResponse<T>? fromMap<T>(
    Map<String, dynamic>? map, {
    required List<String> resultNames,
    required T? Function(dynamic) dataParser,
  }) {
    if (map == null) {
      return null;
    }
    final single = resultNames.singleOrNull;
    T? result;
    final dynamic data = map['data'];
    if (single != null) {
      final dataMap = safeCast<Map<String, dynamic>>(data);
      result = dataMap?.tryParse(single, dataParser);
    } else {
      result = dataParser(data);
    }
    return GraphQLResponse(
      data: result,
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
    this.raw = const <String, dynamic>{},
  });

  final String? message;
  final List<GraphQLErrorLocation?>? locations;
  final Map<String, dynamic> raw;

  static GraphQLError? fromDynamic(dynamic value) {
    return fromMap(safeCast<Map<String, dynamic>>(value));
  }

  static GraphQLError? fromMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    return GraphQLError(
      raw: value,
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

  dynamic operator [](String key) => raw[key];

  void operator []=(String key, dynamic value) => raw[key] = value;

  bool containsValue(dynamic value) => raw.containsValue(value);

  bool containsKey(String key) => raw.containsKey(key);

  Iterable<MapEntry<String, dynamic>> get entries => raw.entries;
}

class GraphQLErrorLocation {
  GraphQLErrorLocation({this.raw = const <String, dynamic>{}});
  final Map<String, dynamic> raw;

  int? get line => raw.tryParse('line', tryParseInt);
  int? get column => raw.tryParse('column', tryParseInt);

  static GraphQLErrorLocation? fromDynamic(dynamic value) {
    return fromMap(safeCast<Map<String, dynamic>>(value));
  }

  static GraphQLErrorLocation? fromMap(Map<String, dynamic>? value) {
    if (value == null) {
      return null;
    }
    return GraphQLErrorLocation(raw: value);
  }

  bool containsValue(dynamic value) => raw.containsValue(value);

  bool containsKey(String key) => raw.containsKey(key);

  dynamic operator [](String key) => raw[key];

  void operator []=(String key, dynamic value) => raw[key] = value;

  Iterable<MapEntry<String, dynamic>> get entries => raw.entries;
}

extension<T> on Iterable<T> {
  T? get singleOrNull {
    T? value;
    for (final element in this) {
      if (value != null) {
        return null;
      }
      value = element;
    }
    return value;
  }

  T? firstWhereOrNull(bool Function(T) predicate) {
    for (final item in this) {
      if (predicate(item)) {
        return item;
      }
    }
    return null;
  }
}

class FragmentDef {
  FragmentDef({
    required this.name,
    required this.refs,
    required this.code,
  });

  final List<String> refs;
  final String name;
  final String code;
}

class FragmentFile {
  FragmentFile({
    required this.defs,
    required this.refMap,
  });

  final List<FragmentDef> defs;
  final Map<String, List<String>> refMap;
}

List<String> findReferencedFragments(
  List<String> refs, [
  List<FragmentDef> localFragments = const [],
  bool skipLocals = true,
  Set<String>? traversedCache,
]) {
  final result =
      findReferencedFragmentsIterate(refs, localFragments, skipLocals, traversedCache)
          .toList();
  return result;
}

Iterable<String> findReferencedFragmentsIterate(
  List<String> refs, [
  List<FragmentDef> localFragments = const [],
  bool skipLocals = true,
  Set<String>? _traversedCache,
]) sync* {
  final traversedCache = _traversedCache ?? <String>{};
  final found = <String>{};
  for (final ref in refs) {
    if (!found.add(ref)) {
      continue;
    }
    final localDef = localFragments.firstWhereOrNull(
      (e) => e.name == ref,
    );
    final isLocal = localDef != null;
    final isGlobal = !isLocal;
    if (skipLocals && isLocal) {
      continue;
    }
    final isTraversed = !traversedCache.add(ref);
    if (isTraversed && isGlobal) {
      continue;
    }
    if (isLocal) {
      yield localDef.code;
      continue;
    }
    for (final file in fragmentFiles) {
      final def = file.defs.firstWhereOrNull(
        (e) => e.name == ref,
      );
      if (def == null) {
        continue;
      }
      yield def.code;
      final innerRefs = file.refMap[def.name];
      if (innerRefs != null) {
        yield* findReferencedFragmentsIterate(
          innerRefs,
          file.defs,
          false,
          traversedCache,
        );
      }
      break;
    }
  }
}
''';
}
