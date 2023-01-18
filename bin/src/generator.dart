import 'dart:io';
import 'package:gql/ast.dart' as gql;
import 'package:gql/language.dart' as gql;
import 'code_writer.dart';
import 'default_value.dart';
import 'field_info.dart';
import 'fragment_def.dart';
import 'fragment_file.dart';
import 'fragment_spread_nodes_finder.dart';
import 'generated_code_helper.dart';
import 'gql_node_extensions.dart';
import 'helpers.dart';
import 'iterable_extensions.dart';
import 'member_type.dart';
import 'operation_info.dart';
import 'primitive_types.dart';
import 'query_input.dart';
import 'string_extensions.dart';
import 'type_info.dart';
import 'uri_extensions.dart';

class Generator {
  Generator({
    required this.packageName,
    required this.packageDir,
    required this.inputDir,
    required this.outputDir,
    required this.isNullSafety,
  });
  late gql.DocumentNode schema;
  late Map<String, gql.TypeDefinitionNode> schemeTypeDefinitions;
  final String packageName;
  final String packageDir;
  final String inputDir;
  final String outputDir;
  final bool isNullSafety;

  void generate() {
    final inputItems = Directory(joinPath([packageDir, inputDir]))
        .listSync()
        .orderBy((a, b) => a.path.compareTo(b.path))
        .where((element) => File(element.path).existsSync())
        .where(
          (e) => ['graphql', 'gql'].contains(
            e.uri.fileExtension.toLowerCase(),
          ),
        );

    final schemePath = inputItems
        .firstWhere((e) => e.uri.fileName.toLowerCase() == 'schema.graphql')
        .path;
    final queryFiles = inputItems.where(
      (e) =>
          e.uri.fileName.toLowerCase() != 'schema.graphql' &&
          !e.uri.fileName.toLowerCase().startsWith('fragment.'),
    );
    final fragmentFiles = inputItems
        .where(
          (e) => e.uri.fileName.toLowerCase().startsWith('fragment.'),
        )
        .toList();
    schema = parseGQLFile(schemePath);
    schemeTypeDefinitions = schema.definitions
        .whereType<gql.TypeDefinitionNode>()
        .toMap(keySelector: (e) => e.name.value, valueSelector: (e) => e);

    final outDir = Directory(joinPath([packageDir, outputDir]));
    if (outDir.existsSync()) {
      outDir.deleteSync(recursive: true);
    }
    final queries = queryFiles.map(_generateFile).toList();
    for (final query in queries) {
      query.resolveOutput(this);
    }
    final fragmentFilesDefs = fragmentFiles.map(_readFragmentsFile).toList();

    final allTypes = _findAllInputsAndOutputs(queries).toList();
    allTypes.forEach(_generateInputOutput);
    queries.forEach(_generateOperation);
    _writeFragmentDefsFile(fragmentFilesDefs);
    _writeExported();
    _writeHelper();
  }

  void _writeFragmentDefsFile(List<FragmentFile> files) {
    final path = joinPath([packageDir, outputDir, 'fragment_defs.dart']);
    final code = CodeWriter();
    final mapped = exportedList.map((e) {
      if (e.startsWith('/')) {
        return e.substring(1);
      }
      return e;
    }).toList();
    mapped.sort((a, b) => a.compareTo(b));

    code.writeLine("import 'helper.dart';");
    code.writeLine('List<FragmentFile>? _fragmentFiles;');
    code.writeBlock(
        start: 'List<FragmentFile> get fragmentFiles',
        write: (code) {
          code.writeBlock(
            start: 'return _fragmentFiles ??=',
            opener: '[',
            closer: '];',
            write: (code) {
              for (final file in files) {
                code.writeBlock(
                  start: 'FragmentFile',
                  opener: '(',
                  closer: '),',
                  write: (code) {
                    code.writeBlock(
                      start: 'defs:',
                      opener: '[',
                      closer: '],',
                      write: (code) {
                        for (final def in file.defs) {
                          code.writeBlock(
                            start: 'FragmentDef',
                            opener: '(',
                            closer: '),',
                            write: (code) {
                              code.writeLine(
                                "name: '${def.name}',",
                              );
                              code.writeBlock(
                                start: 'refs:',
                                opener: '[',
                                closer: '],',
                                write: (code) {
                                  for (final ref in def.refs) {
                                    code.writeLine("'$ref',");
                                  }
                                },
                              );
                              code.writeLine(
                                "code: r'''\n${def.code}\n''',",
                              );
                            },
                          );
                        }
                      },
                    );

                    code.writeBlock(
                      start: 'refMap:',
                      opener: '{',
                      closer: '},',
                      write: (code) {
                        for (final entry in file.refMap.entries) {
                          if (entry.value.isEmpty) {
                            continue;
                          }
                          code.writeBlock(
                            start: "'${entry.key}':",
                            opener: '[',
                            closer: '],',
                            write: (code) {
                              for (final ref in entry.value) {
                                code.writeLine("'$ref',");
                              }
                            },
                          );
                        }
                      },
                    );
                  },
                );
              }
            },
          );
        });

    File(path).writeAsStringSync(code.toString());
  }

  FragmentFile _readFragmentsFile(FileSystemEntity file) {
    final doc = parseGQLFile(file.path);

    final result = FragmentFile(defs: [], refMap: {});
    for (final def in doc.definitions) {
      if (def is gql.FragmentDefinitionNode) {
        final resultDef = _convertFramentDef(def);
        result.defs.add(resultDef);
        final refs = _findReferencedFragments(def).toList();
        result.refMap[def.name.value] = refs;
      }
    }

    return result;
  }

  void _writeExported() {
    final path = joinPath([packageDir, outputDir, 'exported.dart']);
    final code = CodeWriter();
    final mapped = exportedList.map((e) {
      if (e.startsWith('/')) {
        return e.substring(1);
      }
      return e;
    }).toList();
    mapped.sort((a, b) => a.compareTo(b));

    for (final item in mapped) {
      code.writeLine("export '$item';");
    }
    File(path).writeAsStringSync(code.toString());
  }

  void _writeHelper() {
    final path = joinPath([packageDir, outputDir, 'helper.dart']);
    File(path).writeAsStringSync(generatedCodeHelper);
  }

  Map<String, gql.FieldDefinitionNode> findOperation(OperationInfo info) {
    final key =
        (info.type == gql.OperationType.mutation) ? 'Mutation' : 'Query';
    final group = schemeTypeDefinitions[key];
    if (group is gql.ObjectTypeDefinitionNode) {
      final mapped = group.fields.toMap(
        keySelector: (e) => e.name.value,
        valueSelector: (e) => e,
      );
      final result = <String, gql.FieldDefinitionNode>{};
      for (final name in info.queryNames) {
        final operation = mapped[name];
        if (operation == null) {
          throw Exception('operation $name is not defined in the schema.');
        }
        result[name] = operation;
      }
      return result;
    } else {
      throw Exception('un supported type for $key operation list type.');
    }
  }

  List<String> _findAllInputsAndOutputs(List<OperationInfo> queries) {
    final initalInputs =
        queries.mapMany((e) => e.inputs).map((e) => e.type).distinct();

    final allTypes = <String>[];
    for (final input in initalInputs) {
      _referencedInputOutputTypes(input, allTypes);
    }
    final initalOutputs = queries
        .flatMap((e) => e.outputTypes.entries)
        .map((e) => e.value.type)
        .distinct();

    for (final input in initalOutputs) {
      _referencedInputOutputTypes(input, allTypes);
    }

    return allTypes;
  }

  void _referencedNamedInterfaces(String interfaceName, List<String> result) {
    final interfaceDef = schemeTypeDefinitions[interfaceName];
    if (interfaceDef == null) {
      throw Exception(
          'Referenced interface $interfaceDef is not defined in the scheme.');
    }
    if (interfaceDef is! gql.InterfaceTypeDefinitionNode) {
      throw Exception(
          'unsupported interface type: ${interfaceDef.runtimeType}');
    }
    _referencedInterfaces(interfaceDef, result);
  }

  void _referencedInterfaces(
      gql.InterfaceTypeDefinitionNode interface, List<String> result) {
    final name = interface.name.value;
    if (result.contains(name)) {
      return;
    }
    result.add(name);
    for (final field in interface.fields) {
      final type = field.type;
      _referencedInputOutputTypes(type, result);
    }
    for (final interfaceName in interface.interfaces) {
      _referencedNamedInterfaces(interfaceName.name.value, result);
    }
  }

  void _referencedInputOutputTypes(gql.TypeNode type, List<String> result) {
    final String name;
    if (type is gql.ListTypeNode) {
      _referencedInputOutputTypes(type.type, result);
      return;
    } else if (type is gql.NamedTypeNode) {
      name = type.name.value;
    } else {
      throw Exception('un supported type ${type.runtimeType}');
    }

    if (PrimitveTypes.values.any((e) => e.name == name)) {
      return;
    }
    if (result.contains(name)) {
      return;
    }
    final def = schemeTypeDefinitions[name];
    if (def is gql.ObjectTypeDefinitionNode) {
      result.add(name);

      for (final interfaceName in def.interfaces) {
        _referencedNamedInterfaces(interfaceName.name.value, result);
      }

      for (final field in def.fields) {
        final type = field.type;
        _referencedInputOutputTypes(type, result);
      }
    } else if (def is gql.InputObjectTypeDefinitionNode) {
      result.add(name);

      for (final field in def.fields) {
        final type = field.type;
        _referencedInputOutputTypes(type, result);
      }
    } else if (def is gql.EnumTypeDefinitionNode) {
      result.add(name);
    } else if (def is gql.InterfaceTypeDefinitionNode) {
      result.add(name);
      _referencedInterfaces(def, result);
    } else if (def == null) {
      throw Exception('input model $name not found in the scheme.');
    } else {
      throw Exception(
          'not supported input type for [$name]: ${def.runtimeType}');
    }
  }

  void writeImports(CodeWriter writer) {
    writer.writeLine('// ignore_for_file: unused_import');
    writer.writeLine("import '../exported.dart';");
    writer.writeLine("import '../helper.dart';");
    writer.writeLine();
  }

  void _generateEnum(String outputPath, gql.EnumTypeDefinitionNode def) {
    final writer = CodeWriter();
    writeImports(writer);
    final name = fixName(def.name.value, MemberType.enumeration);
    writer.writeBlock(
      start: 'enum $name',
      write: (writer) {
        for (final value in def.values) {
          final fixed = fixName(value.name.value, MemberType.field);
          writer.writeLine('$fixed,');
        }
      },
    );
    writer.writeLine();
    writer.writeBlock(
      start: 'extension ${name}Serializer on $name',
      write: (writer) {
        writer.writeBlock(
          start: 'String get rawValue',
          write: (writer) {
            writer.writeBlock(
              start: 'switch (this)',
              write: (writer) {
                for (final value in def.values) {
                  final fixed = fixName(value.name.value, MemberType.field);
                  writer.writeBlock(
                    start: 'case $name.$fixed',
                    opener: ':',
                    closer: '',
                    write: (writer) {
                      writer.writeLine("return '${value.name.value}';");
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
    writer.writeLine();
    final optional = isNullSafety ? '?' : '';
    writer.writeBlock(
      start: '$name$optional tryParse$name(dynamic value)',
      write: (writer) {
        writer.writeBlock(
          start: 'if (value is $name)',
          write: (writer) {
            writer.writeLine('return value;');
          },
        );

        writer.writeBlock(
          start: 'if (value is String)',
          write: (writer) {
            writer.writeBlock(
              start: 'switch (value)',
              write: (writer) {
                for (final value in def.values) {
                  final fixed = fixName(value.name.value, MemberType.field);
                  writer.writeBlock(
                    start: "case '${value.name.value}'",
                    opener: ':',
                    closer: '',
                    write: (writer) {
                      writer.writeLine('return $name.$fixed;');
                    },
                  );
                }
              },
            );
          },
        );

        writer.writeLine('return null;');
      },
    );
    File(outputPath).writeAsStringSync(writer.toString());
  }

  String getDefPath(String name, String subFolder) {
    final def = schemeTypeDefinitions[name];
    if (def == null) {
      throw Exception('definition $name not found in the schema.');
    }
    final fixed = fixName(def.name.value, def.memberType);
    return getDefPathForResolvedType(fixed, subFolder);
  }

  String getDefPathForResolvedType(String name, String subFolder) {
    final dir = joinPath([packageDir, outputDir, subFolder]);
    tryCreateDir(dir);
    addExported(subFolder, name + '.dart');
    return joinPath([dir, name + '.dart']);
  }

  var exportedList = <String>[];
  void addExported(String subFolder, String name) {
    exportedList.add(joinPath([subFolder, name]));
  }

  String getOperationPath(String name, String subFolder) {
    final dir = joinPath([packageDir, outputDir, subFolder]);
    tryCreateDir(dir);
    addExported(subFolder, name + '.dart');
    return joinPath([dir, name + '.dart']);
  }

  String? _serlizerTypeMapping(gql.TypeNode type, {int? level}) {
    var nullCheck = type.isNullable && isNullSafety ? '?' : '';

    if (type is gql.NamedTypeNode) {
      final primitive = PrimitveTypes.values
          .firstWhereOrNull((e) => e.name == type.name.value);
      final name = type.name.value;
      if (primitive != null) {
        return null;
      } else {
        final inputType = schemeTypeDefinitions[name];
        if (inputType == null) {
          throw Exception('type $name not found in the scheme');
        }
        nullCheck = '?';
        if (inputType.isEnumDefinition) {
          return nullCheck + '.rawValue';
        }

        return nullCheck + '.toMap()';
      }
    } else if (type is gql.ListTypeNode) {
      final inner = _serlizerTypeMapping(type.type, level: (level ?? 0) + 1);
      if (inner == null) {
        return null;
      }
      final varName = 'e${level ?? ''}';
      return nullCheck + '.map(($varName)=> $varName$inner).toList()';
    } else {
      throw Exception('Un supported type ${type.runtimeType}');
    }
  }

  void _writeFieldSerializer(
    CodeWriter writer,
    FieldInfo field,
  ) {
    final type = field.type;
    writer
      ..write(fixName(field.codeGenName, MemberType.field))
      ..write(_serlizerTypeMapping(type) ?? '');
  }

  void _generateInterface(
    String outputPath,
    gql.InterfaceTypeDefinitionNode def,
  ) {
    final code = CodeWriter();
    writeImports(code);
    final name = fixName(def.name.value, MemberType.interface);
    final interfacesList = def.interfaces
        .map((e) => fixName(e.name.value, MemberType.interface))
        .toList();
    final interfacesRef =
        interfacesList.isEmpty ? '' : ' implements ' + interfacesList.join(',');
    code.writeBlock(
      start: 'abstract class $name$interfacesRef',
      write: (code) {
        for (final field in def.fields) {
          final type = field.type;
          code
            ..write(_mapType(type))
            ..write(' get ')
            ..write(fixName(field.name.value, MemberType.field))
            ..writeLine(';');
        }
      },
    );
    File(outputPath).writeAsStringSync(code.toString());
  }

  bool isOverriden(
    String fieldName,
    List<String> interfaces,
    Set<String> searchCache,
  ) {
    for (final interface in interfaces) {
      if (searchCache.add(interface)) {
        final def = schemeTypeDefinitions[interface];
        if (def == null || def is! gql.InterfaceTypeDefinitionNode) {
          throw Exception('interface $interface is not defined in the schema.');
        }
        final found = def.fields.any((e) => e.name.value == fieldName);
        if (found) {
          return true;
        }
        final subInterfaces = def.interfaces.map((e) => e.name.value).toList();
        if (isOverriden(fieldName, subInterfaces, searchCache)) {
          return true;
        }
      }
    }
    return false;
  }

  void generateClass(
    String outputPath,
    String name,
    List<FieldInfo> fields,
    List<String> interfaces,
    MemberType memberType,
  ) {
    final writer = CodeWriter();
    final fixedName = fixName(name, memberType);
    writeImports(writer);

    final interfacesRef =
        interfaces.isEmpty ? '' : ' implements ' + interfaces.join(',');

    writer.writeBlock(
      start: 'class $fixedName$interfacesRef',
      write: (writer) {
        if (fields.isEmpty) {
          writer.writeLine('const $fixedName();');
        } else {
          writer.writeBlock(
            start: 'const $fixedName',
            opener: '({',
            closer: '});',
            write: (writer) {
              for (final field in fields) {
                final fieldType = field.type;
                if (fieldType.isNonNull) {
                  var addRequired = true;
                  if (fieldType is gql.NamedTypeNode) {
                    final isPrimitve = PrimitveTypes.values
                        .any((e) => e.name == fieldType.name.value);
                    if (!isPrimitve) {
                      addRequired = false;
                    }
                  }
                  if (addRequired) {
                    if (!isNullSafety) {
                      writer.write('@');
                    }
                    writer.write('required ');
                  }
                }
                writer
                  ..write('this.')
                  ..write(fixName(field.codeGenName, MemberType.field));

                final defaultValue = field.defaultValue;
                if (defaultValue != null && defaultValue is! NullDefaultValue) {
                  writer.write(' = ');
                  defaultValue.writeTo(this, writer);
                }

                writer.writeLine(',');
              }
            },
          );
        }

        for (final field in fields) {
          final type = field.type;
          if (isOverriden(field.name, interfaces, {})) {
            writer.writeLine('@override');
          }
          writer
            ..write('final ')
            ..write(_mapType(type))
            ..write(' ')
            ..write(fixName(field.codeGenName, MemberType.field))
            ..writeLine(';');
        }
        final nullCheck = isNullSafety ? '?' : '';
        // ===== fromDynamic : start
        writer.writeLine();
        writer.writeBlock(
          start: 'static $fixedName$nullCheck fromDynamic(dynamic value)',
          write: (writer) {
            writer.writeLine(
                'return fromMap(safeCast<Map<String, dynamic>>(value));');
          },
        );

        // ===== fromDynamic : end

//======= fromMap: Start
        writer.writeLine();
        const mapName = 'map';
        writer.writeBlock(
          start:
              'static $fixedName$nullCheck fromMap(Map<String, dynamic>$nullCheck $mapName)',
          write: (writer) {
            writer.writeBlock(
              start: 'if ($mapName == null)',
              write: (writer) {
                writer.writeLine('return null;');
              },
            );
            writer.writeBlock(
              start: 'return $fixedName',
              opener: '(',
              closer: ');',
              write: (writer) {
                for (final field in fields) {
                  writer.write(fixName(field.codeGenName, MemberType.field));
                  writer.write(': ');
                  _writeFieldParser(
                    writer,
                    mapName,
                    field,
                  );
                  _writeNullCheckDefaultValueIfNeeded(writer, field);
                  writer.writeLine(',');
                }
              },
            );
          },
        );
//======= fromMap: End

        writer.writeLine();
        writer.writeBlock(
          start: 'Map<String, dynamic> toMap()',
          write: (writer) {
            writer.writeBlock(
              start: 'return <String, dynamic>',
              opener: '{',
              closer: '};',
              write: (writer) {
                for (final field in fields) {
                  writer.write("'${field.name}'");
                  writer.write(': ');
                  _writeFieldSerializer(
                    writer,
                    field,
                  );
                  writer.writeLine(',');
                }
              },
            );
          },
        );
      },
    );
    final code = writer.toString();
    File(outputPath).writeAsStringSync(code);
  }

  String _getTypeParser(
    gql.TypeNode type,
  ) {
    if (type is gql.NamedTypeNode) {
      final name = type.name.value;
      final primitve =
          PrimitveTypes.values.firstWhereOrNull((e) => e.name == name);
      if (primitve != null) {
        return primitve.parser;
      } else {
        final inputType = schemeTypeDefinitions[name];
        if (inputType == null) {
          throw Exception('type $name not found in the scheme');
        }

        final typeName = fixName(type.name.value, inputType.memberType);
        if (inputType.isEnumDefinition) {
          return 'tryParse$typeName';
        } else {
          return typeName + '.fromDynamic';
        }
      }
    } else if (type is gql.ListTypeNode) {
      final element = _getTypeParser(type.type);
      return 'arrayParser($element)';
    } else {
      throw Exception('Un supported type ${type.runtimeType}');
    }
  }

  String? _getDefaultValue(
    gql.TypeNode type,
  ) {
    if (type is gql.NamedTypeNode) {
      final name = type.name.value;
      final primitve =
          PrimitveTypes.values.firstWhereOrNull((e) => e.name == name);
      if (primitve != null) {
        return primitve.defaultValue;
      } else {
        final inputType = schemeTypeDefinitions[name];
        if (inputType == null) {
          throw Exception('type $name not found in the scheme');
        }
        // Note for team: enums will be treated as other models, always nullabel
        // has no default values while parsing !
        // keeping the following code to know how to get the defaul values again.
        //final typeName = fixName(type.name.value, inputType.memberType);
        // if (inputType is gql.EnumTypeDefinitionNode) {
        //   final fieldName = inputType.values.firstOrNull()?.name.value;
        //   if (fieldName == null) {
        //     throw Exception('Enum ${inputType.name.value} has no case');
        //   }
        //   final fixedName = fixName(fieldName, MemberType.field);
        //   return '$typeName.' + fixedName;
        // }
        return null;
      }
    } else if (type is gql.ListTypeNode) {
      return '[]';
    } else {
      throw Exception('Un supported type ${type.runtimeType}');
    }
  }

  void _writeFieldParser(
    CodeWriter writer,
    String mapName,
    FieldInfo field,
  ) {
    final type = field.type;
    writer
      ..write('$mapName.tryParse(')
      ..write("'${field.name}', ")
      ..write(_getTypeParser(type))
      ..write(')');
  }

  String _mapType(gql.TypeNode type, {bool addNullCheck = true}) {
    var nullableSuffix =
        addNullCheck && isNullSafety && type.isNullable ? '?' : '';
    if (type is gql.NamedTypeNode) {
      final String result;
      final name = type.name.value;
      final primitive =
          PrimitveTypes.values.firstWhereOrNull((e) => e.name == name);
      if (primitive != null) {
        result = primitive.dartName;
      } else {
        nullableSuffix = addNullCheck && isNullSafety ? '?' : '';
        final inputType = schemeTypeDefinitions[name];
        if (inputType != null) {
          result = fixName(type.name.value, inputType.memberType);
        } else {
          throw Exception('type $name not found in the scheme');
        }
      }
      return result + nullableSuffix;
    } else if (type is gql.ListTypeNode) {
      final element = _mapType(type.type);
      return 'List<$element>' + nullableSuffix;
    } else {
      throw Exception('Un supported type ${type.runtimeType}');
    }
  }

  String fixName(String name, MemberType type) {
    switch (type) {
      case MemberType.enumeration:
      case MemberType.interface:
        return name.fixName(type);
      case MemberType.field:
        return name.fixName(type);
      case MemberType.inputModel:
        return name.fixName(type).addSuffix('Input').addSuffix('Model');
      case MemberType.outputModel:
        return name.fixName(type).addSuffix('Model');
      case MemberType.query:
        return name.fixName(type).addSuffix('Query');
      case MemberType.mutation:
        return name.fixName(type).addSuffix('Mutation');
      case MemberType.subscription:
        return name.fixName(type).addSuffix('Subscription');
    }
  }

  String? _findFieldAliase(List<gql.DirectiveNode> directives) {
    return safeCast<gql.StringValueNode>(directives
            .firstWhereOrNull((e) => e.name.value == 'custom_alias')
            ?.arguments
            .firstWhereOrNull((e) => e.name.value == 'name')
            ?.value)
        ?.value;
  }

  void _generateInputOutput(String name) {
    final def = schemeTypeDefinitions[name];
    if (def == null) {
      throw Exception('input model $name not found in the scheme.');
    }
    final path = getDefPath(name, def.memberType.subFolderName);
    if (def is gql.ObjectTypeDefinitionNode) {
      generateClass(
        path,
        name,
        def.fields
            .map(
              (e) => FieldInfo(
                name: e.name.value,
                type: e.type,
                aliase: _findFieldAliase(e.directives),
              ),
            )
            .toList(),
        def.interfaces.map((e) => e.name.value).toList(),
        def.memberType,
      );
    } else if (def is gql.InputObjectTypeDefinitionNode) {
      generateClass(
        path,
        name,
        def.fields
            .map(
              (e) => FieldInfo(
                name: e.name.value,
                type: e.type,
                aliase: _findFieldAliase(e.directives),
                defaultValue: _mapDefaultValue(
                  e.defaultValue,
                  e.type,
                ),
              ),
            )
            .toList(),
        [],
        def.memberType,
      );
    } else if (def is gql.EnumTypeDefinitionNode) {
      _generateEnum(path, def);
    } else if (def is gql.InterfaceTypeDefinitionNode) {
      _generateInterface(path, def);
    } else {
      throw Exception(
          'not supported input type for [$name]: ${def.runtimeType}');
    }
  }

  void _generateAggregateOperationResultType(
      String resultName, Map<String, TypeInfo> subTypes) {
    final path = getDefPathForResolvedType(resultName, 'AggregateOutputModels');
    generateClass(
      path,
      resultName,
      subTypes.entries
          .map(
            (e) => FieldInfo(
              name: e.key,
              type: e.value.type,
            ),
          )
          .toList(),
      [],
      MemberType.outputModel,
    );
  }

  void _generateOperation(OperationInfo operation) {
    final fileName = fixName(
      Uri.file(operation.filePath).fileNameWithoutExtension,
      operation.memberType,
    );
    final path = getOperationPath(
      fileName,
      operation.memberType.name.capitalize(),
    );

    final code = CodeWriter();
    writeImports(code);
    //final opName = fixName(operation.queryName, operation.memberType);

    final String noneNullOutputName;
    final String outputName;
    final String typeParser;
    if (operation.outputTypes.length == 1) {
      final type = operation.outputTypes.entries.first.value.type;
      noneNullOutputName = _mapType(type, addNullCheck: false);
      outputName = _mapType(type);
      typeParser = _getTypeParser(type);
    } else {
      final name = '${fileName}OutputModel';
      _generateAggregateOperationResultType(name, operation.outputTypes);
      noneNullOutputName = name;
      outputName = '$name?';
      typeParser = '$name.fromDynamic';
    }

    code.writeBlock(
      start: 'class $fileName implements BaseRequest<$noneNullOutputName>',
      write: (code) {
        if (operation.inputs.isEmpty) {
          code.writeLine('const $fileName();');
        } else {
          code.writeBlock(
            start: 'const $fileName',
            opener: '({',
            closer: '});',
            write: (code) {
              for (final field in operation.inputs) {
                if (field.type.isNonNull) {
                  if (!isNullSafety) {
                    code.write('@');
                  }
                  code.write('required ');
                }
                final fieldName = fixName(field.name, MemberType.field);
                code.write('this.');
                code.write(fieldName);
                final defaultValue = field.defaultValue;
                if (defaultValue != null && defaultValue is! NullDefaultValue) {
                  code.write(' = ');
                  defaultValue.writeTo(this, code);
                }
                code.writeLine(',');
              }
            },
          );
        }

        code.writeLine();
        for (final field in operation.inputs) {
          final fieldType = field.type;
          final type = _mapType(fieldType);
          code.write('final ');
          code.write(type);
          code.write(' ');
          final fieldName = fixName(field.name, MemberType.field);
          code.write(fieldName);
          code.writeLine(';');
          code.writeLine();
        }

        code.writeLine('@override');
        final mappedNames = operation.queryNames.map((e) => "'$e'").join(',');
        code.writeLine('List<String> get operationNames => [$mappedNames];');

        code.writeLine();
        final externalRefs = operation.directOperationFragmentRefsExternal;
        if (externalRefs.isEmpty) {
          code.writeLine('@override');
          code.writeLine("String get operation => r'''");
        } else {
          code.writeLine('static String? _operationCached;');
          code.writeLine('@override');
          code.writeLine("String get operation => _operationCached ??= r'''");
        }
        final formatted = reformatGQLFile(operation.filePath);
        code.write(formatted.escapeText(singleLine: false), addTabs: false);
        code.writeLine('');
        if (externalRefs.isEmpty) {
          code.writeLine("''';");
        } else {
          code.writeLine("\n''' + findReferencedFragments([" +
              externalRefs.map((e) => "'$e'").join(',') +
              r"]).join('\n');");
        }

        code.writeLine();
        code.writeLine('@override');
        code.writeBlock(
          start: 'Map<String, dynamic> get inputs => <String, dynamic>',
          opener: '{',
          closer: '};',
          write: (code) {
            for (final field in operation.inputs) {
              code.write("'${field.name}': ");
              _writeFieldSerializer(
                code,
                FieldInfo(
                  name: field.name,
                  type: field.type,
                ),
              );
              code.writeLine(', ');
            }
          },
        );

        code.writeLine();
        code.writeLine('@override');

        code.writeBlock(
          start: '$outputName parseResult(dynamic value)',
          write: (code) {
            code.write('return ');
            code.write(typeParser);
            code.writeLine('(value);');
          },
        );
      },
    );

    File(path).writeAsStringSync(code.toString());
  }

  String reformatGQLFile(String path) {
    final code = File(path).readAsStringSync();
    final doc = gql.parseString(code);
    return gql.printNode(doc);
  }

  Iterable<String> _findReferencedFragments(gql.Node def) sync* {
    final finder = FragmentSpreadNodeFinder();
    def.accept(finder);
    final refs = finder.nodes;
    for (final ref in refs) {
      yield ref.name.value;
    }
  }

  FragmentDef _convertFramentDef(gql.FragmentDefinitionNode def) {
    return FragmentDef(
      name: def.name.value,
      code: gql.printNode(def),
      refs: _findReferencedFragments(def).toList(),
    );
  }

  OperationInfo _generateFile(FileSystemEntity item) {
    final doc = parseGQLFile(item.path);
    final noneFragments =
        doc.definitions.where((e) => e is! gql.FragmentDefinitionNode).toList();
    final fragments =
        doc.definitions.whereType<gql.FragmentDefinitionNode>().toList();

    if (noneFragments.length != 1) {
      throw Exception(
          'graph ql file must contian one definition: ${item.uri.fileName}');
    }
    final def = noneFragments.first;

    if (def is gql.OperationDefinitionNode) {
      final namedInputs = <QueryInput>[];
      _findReferencedFragments(def);
      final inputs = def.variableDefinitions;
      for (final input in inputs) {
        final name = input.variable.name.value;
        final type = input.type;

        namedInputs.add(
          QueryInput(
            name: name,
            type: type,
            defaultValue: _mapDefaultValue(
              input.defaultValue?.value,
              type,
            ),
          ),
        );
      }

      final names = <String>[];
      for (final selectedQuery in def.selectionSet.selections) {
        if (selectedQuery is gql.FieldNode) {
          final name = selectedQuery.name.value;
          names.add(name);
        } else {
          throw Exception(
              'unsupported selection type: ${def.runtimeType}, file: ${item.path}');
        }
      }
      return OperationInfo(
        filePath: item.path,
        queryNames: names,
        inputs: namedInputs,
        type: def.type,
        directOperationFragmentRefs: _findReferencedFragments(def).toList(),
        fragmetDefs: fragments.map(_convertFramentDef).toList(),
      );
    } else {
      throw Exception(
          'unsupported operation node type: ${def.runtimeType}, file: ${item.path}');
    }
  }

  void _writeNullCheckDefaultValueIfNeeded(CodeWriter writer, FieldInfo field) {
    if (isNullSafety && field.type.isNonNull) {
      final defaultValue = _getDefaultValue(field.type);
      if (defaultValue != null) {
        writer.write(' ?? $defaultValue');
      }
    }
  }

  DefaultValue? _mapDefaultValue(gql.ValueNode? value, gql.TypeNode? type) {
    if (value == null) {
      return null;
    }
    if (value is gql.IntValueNode) {
      return IntDefaultValue(int.parse(value.value));
    } else if (value is gql.StringValueNode) {
      return StringDefaultValue(value.value);
    } else if (value is gql.EnumValueNode) {
      if (type == null || type is! gql.NamedTypeNode) {
        throw Exception(
            'unsupported type for enum default value, ${type?.runtimeType}');
      }
      return EnumDefaultValue(
        enumType: type.name.value,
        enumValue: value.name.value,
      );
    } else if (value is gql.NullValueNode) {
      return NullDefaultValue();
    } else if (value is gql.FloatValueNode) {
      return FloatDefaultValue(double.parse(value.value));
    } else if (value is gql.BooleanValueNode) {
      return BooleanDefaultValue(value.value);
    }
    throw Exception(
        'Un supported default value node type: ${value.runtimeType}.');
  }

  gql.DocumentNode parseGQLFile(String filePath) {
    final file = File(filePath);
    final content = file.readAsStringSync();
    final gqlDoc = gql.parseString(content);
    return gqlDoc;
  }

  String joinPath(List<String> parts) {
    var result = '';
    for (final part in parts) {
      if (result.isEmpty) {
        result = part;
        continue;
      }
      final ends = result.endsWith('/');
      final starts = part.startsWith('/');
      if (starts && ends) {
        result += part.substring(1);
      } else if (starts || ends) {
        result += part;
      } else {
        result += '/$part';
      }
    }
    return result;
  }
}
