import 'dart:io';

import 'package:yaml/yaml.dart' as yaml;

import 'main.dart' as app;
import 'src/generator.dart';
import 'src/helpers.dart';

void main(List<String> args) {
  final yamlGenerators = loadConfig().toList();
  if (yamlGenerators.isEmpty) {
    app.main(args);
  }
  for (final gen in yamlGenerators) {
    try {
      gen.generate();
    } catch (ex, trac) {
      // ignore: avoid_print
      print('Exception: $ex');
      // ignore: avoid_print
      print('Trace: \n$trac');
    }
  }
}

Iterable<Generator> loadConfig() sync* {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    return;
  }
  final yamlContent = file.readAsStringSync();
  final dynamic mainYamlDoc = yaml.loadYaml(yamlContent);
  final yml = safeCast<yaml.YamlMap>(mainYamlDoc);
  if (yml == null) {
    return;
  }
  final config = safeCast<yaml.YamlList>(yml['flutter_gql_code_generator']);
  if (config == null || config.isEmpty) {
    return;
  }
  for (final item in config) {
    final map = safeCast<yaml.YamlMap>(item);
    if (map == null) {
      continue;
    }
    final packageName = safeCast<String>(map['packageName']);
    final packageDir = safeCast<String>(map['packageDir']);
    final inputDir = safeCast<String>(map['inputDir']);
    final outputDir = safeCast<String>(map['outputDir']);
    bool toBoolean(String value) => ['true', 'on', '1'].contains(value);
    final isNullSafety = toBoolean(map['isNullSafety']?.toString() ?? '');
    final listFilesRecursively =
        toBoolean(map['listFilesRecursively']?.toString() ?? '');
    final enableFieldsAlias =
        toBoolean(map['enableFieldsAlias']?.toString() ?? '');
    final mutableOutputModelFields =
        toBoolean(map['mutableOutputModelFields']?.toString() ?? '');
    final enableFragments = toBoolean(map['enableFragments']?.toString() ?? '');
    if ( //
        packageName == null || //
            packageDir == null || //
            inputDir == null || //
            outputDir == null //
        ) {
      continue;
    }
    yield Generator(
      packageName: packageName,
      packageDir: packageDir,
      inputDir: inputDir,
      outputDir: outputDir,
      isNullSafety: isNullSafety,
      listFilesRecursively: listFilesRecursively,
      enableFieldsAlias: enableFieldsAlias,
      enableFragments: enableFragments,
      mutableOutputModelFields: mutableOutputModelFields,
    );
  }
}
