import 'package:args/args.dart';
import 'src/generator.dart';
import 'src/helpers.dart';

void main(List<String> args) {
  final parser = ArgParser();
  parser.addOption('packageDir', abbr: 'd');
  parser.addOption('packageName', abbr: 'p');
  parser.addOption('inputDir', abbr: 'i');
  parser.addOption('outputDir', abbr: 'o');
  parser.addFlag('isNullSafety', abbr: 'n');
  parser.addFlag('listFilesRecursively', abbr: 'r');
  parser.addFlag('enableFieldsAlias', abbr: 'a');
  parser.addFlag('enableFragments', abbr: 'f');
  parser.addFlag('mutableOutputModelFields');

  final results = parser.parse(args);

  final dynamic packageDir = results['packageDir'];
  final dynamic packageName = results['packageName'];
  final dynamic inputDir = results['inputDir'];
  final dynamic outputDir = results['outputDir'];
  final isNullSafety = safeCast<bool>(results['isNullSafety']) ?? false;
  final listFilesRecursively =
      safeCast<bool>(results['listFilesRecursively']) ?? false;
  final enableFieldsAlias =
      safeCast<bool>(results['enableFieldsAlias']) ?? false;
  final enableFragments = safeCast<bool>(results['enableFragments']) ?? false;
  final mutableOutputModelFields =
      safeCast<bool>(results['mutableOutputModelFields']) ?? false;
  if (inputDir == null || inputDir is! String) {
    throw Exception('inputDir is mandatory');
  }
  if (outputDir == null || outputDir is! String) {
    throw Exception('outputDir is mandatory');
  }
  if (packageName == null || packageName is! String) {
    throw Exception('packageName is mandatory');
  }
  if (packageDir == null || packageDir is! String) {
    throw Exception('packageDir is mandatory');
  }

  Generator(
    packageName: packageName,
    packageDir: packageDir,
    inputDir: inputDir,
    outputDir: outputDir,
    isNullSafety: isNullSafety,
    listFilesRecursively: listFilesRecursively,
    enableFieldsAlias: enableFieldsAlias,
    enableFragments: enableFragments,
    mutableOutputModelFields: mutableOutputModelFields,
  ).generate();
}
