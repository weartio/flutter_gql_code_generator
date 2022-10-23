import 'member_type.dart';

extension StringExtensions on String {
  String addSuffix(String suffix) {
    if (endsWith(suffix)) {
      return this;
    }
    return this + suffix;
  }

  String escapeText({bool singleLine = true}) {
    final value = replaceAll(r'\', r'\\')
        //https://www.windmill.co.uk/ascii-control-codes.html
        .replaceAll('"', r'\"')
        .replaceAll("'", r"\'")
        .replaceAll('\t', r'\t')
        .replaceAll('\x00', r'\x00')
        .replaceAll('\x01', r'\x01')
        .replaceAll('\x02', r'\x02')
        .replaceAll('\x03', r'\x03')
        .replaceAll('\x04', r'\x04')
        .replaceAll('\x05', r'\x05')
        .replaceAll('\x06', r'\x06')
        .replaceAll('\x07', r'\x07')
        .replaceAll('\x08', r'\x08')
        .replaceAll('\x09', r'\x09')
        //.replaceAll('\x0A', r'\x0A') // same as \n
        .replaceAll('\x0B', r'\x0B')
        .replaceAll('\x0C', r'\x0C')
        //.replaceAll('\x0D', r'\x0D') // same as \r
        .replaceAll('\x0E', r'\x0E')
        .replaceAll('\x0F', r'\x0F')
        .replaceAll('\x10', r'\x10')
        .replaceAll('\x11', r'\x11')
        .replaceAll('\x12', r'\x12')
        .replaceAll('\x13', r'\x13')
        .replaceAll('\x14', r'\x14')
        .replaceAll('\x15', r'\x15')
        .replaceAll('\x16', r'\x16')
        .replaceAll('\x17', r'\x17')
        .replaceAll('\x18', r'\x18')
        .replaceAll('\x19', r'\x19')
        .replaceAll('\x1A', r'\x1A')
        .replaceAll('\x1B', r'\x1B')
        .replaceAll('\x1C', r'\x1C')
        .replaceAll('\x1D', r'\x1D')
        .replaceAll('\x1E', r'\x1E')
        .replaceAll('\x1F', r'\x1F');
    if (singleLine) {
      return value.replaceAll('\n', r'\n').replaceAll('\r', r'\r');
    } else {
      return value;
    }
  }
}

enum FixNameTarget {
  typeDecl,
  memberDecl,
}

extension FixName on String {
  String fixName(MemberType target) {
    switch (target) {
      case MemberType.field:
        return _fixName(FixNameTarget.memberDecl);
      case MemberType.inputModel:
      case MemberType.outputModel:
      case MemberType.mutation:
      case MemberType.query:
      case MemberType.enumeration:
      case MemberType.subscription:
      case MemberType.interface:
        return _fixName(FixNameTarget.typeDecl);
    }
  }

  String _fixName(FixNameTarget target) {
    var wasLetter = false;
    var wasLower = false;
    var acm = '';
    final parts = <String>[];

    void push() {
      if (acm.isNotEmpty) {
        parts.add(acm);
      }
      acm = '';
    }

    for (final c in codeUnits) {
      final isUpper = c.isUpperCase();
      if (c.isDigit()) {
        acm += String.fromCharCode(c);
        wasLetter = false;
        wasLower = false;
      } else if (c.isLowerCase() || isUpper) {
        if (isUpper) {
          if (wasLower || !wasLetter) {
            push();
          }
          wasLower = false;
        } else {
          if (!wasLetter) {
            push();
          }
          wasLower = true;
        }
        acm += String.fromCharCode(c);
        wasLetter = true;
      } else {
        push();
        wasLetter = false;
        wasLower = false;
      }
    }
    push();
    if (target == FixNameTarget.typeDecl) {
      return parts.map((p) => p.capitalize()).join().escapeKeyWords();
    } else {
      return (parts.first.toLowerCase() +
              parts.sublist(1).map((p) => p.capitalize()).join())
          .escapeKeyWords();
    }
  }

  String escapeKeyWords() {
    //https://docs.swift.org/swift-book/ReferenceManual/LexicalStructure.html#:~:text=Keywords%20reserved%20in%20particular%20contexts,unowned%20%2C%20weak%20%2C%20and%20willSet%20.
    final decls = [
      'associatedtype',
      'class',
      'deinit',
      'enum',
      'extension',
      'fileprivate',
      'func',
      'import',
      'init',
      'inout',
      'internal',
      'let',
      'open',
      'operator',
      'private',
      'precedencegroup',
      'protocol',
      'public',
      'rethrows',
      'static',
      'struct',
      'subscript',
      'typealias',
      'var'
    ];
    final statements = [
      'break',
      'case',
      'catch',
      'continue',
      'default',
      'defer',
      'do',
      'else',
      'fallthrough',
      'for',
      'guard',
      'if',
      'in',
      'repeat',
      'return',
      'throw',
      'switch',
      'where',
      'and',
      'while',
    ];
    final expAndTypes = [
      'Any',
      'as',
      'catch',
      'false',
      'is',
      'nil',
      'rethrows',
      'self',
      'Self',
      'super',
      'throw',
      'throws',
      'true',
      'try',
    ];

    if ([decls, statements, expAndTypes].any((e) => e.contains(this))) {
      return '`$this`';
    }
    return this;
  }

  String capitalize() {
    if (isEmpty) {
      return '';
    }
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }

  bool isDigit(int idx) => (codeUnitAt(idx) ^ 0x30) <= 9;
}

extension CharacterUtils on int {
  bool isDigit() => this >= 0x30 && this <= 0x39;
  bool isLowerCase() => this >= 0x61 && this <= 0x7a;
  bool isUpperCase() => this >= 0x41 && this <= 0x5a;
}
