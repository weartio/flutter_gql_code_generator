import 'iterable_extensions.dart';

extension UriExtensions on Uri {
  String get fileName => pathSegments.last;
  String get fileExtension => fileName.split('.').lastOrNull ?? '';
  String get fileNameWithoutExtension {
    final listed = fileName.split('.');
    if (listed.length > 1) {
      listed.removeLast();
    }
    return listed.join('.');
  }
}
