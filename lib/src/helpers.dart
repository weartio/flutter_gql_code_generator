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
