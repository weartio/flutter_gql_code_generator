import 'dart:io';

void tryCreateDir(String path) {
  final dir = Directory(path);
  if (dir.existsSync()) {
    return;
  }
  final parent = dir.parent;
  tryCreateDir(parent.path);
  dir.createSync();
}

T? safeCast<T>(dynamic value) {
  if (value is T) {
    return value;
  }
  return null;
}

extension IterableExtensions<T> on Iterable<T> {
  Iterable<TR> flatMap<TR>(Iterable<TR> Function(T) mapper) sync* {
    for (final item in this) {
      for (final subItem in mapper(item)) {
        yield subItem;
      }
    }
  }
}
