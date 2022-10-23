class CodeWriter {
  final _buffer = StringBuffer();
  @override
  String toString() => _buffer.toString();

  var atLineStart = false;
  var indentation = 0;
  void write(String value, {bool addTabs = true}) {
    if (addTabs) {
      _writeTabs();
    }
    _buffer.write(value);
    if (value.isNotEmpty) {
      atLineStart = ['\n', '\r'].contains(value[value.length - 1]);
    }
  }

  void _writeTabs() {
    if (atLineStart) {
      _buffer.write('  ' * indentation);
    }
    atLineStart = false;
  }

  void writeLine([String value = '']) {
    write(value);
    write('\n');
    atLineStart = true;
  }

  void writeBlockStart(String value, [String open = ' {']) {
    write(value);
    writeLine(open);
    indentation += 1;
  }

  void closeBlock([String close = '}']) {
    indentation -= 1;
    writeLine(close);
  }

  void writeBlock(
      {required String start,
      String opener = ' {',
      String closer = '}',
      required void Function(CodeWriter writer) write}) {
    writeBlockStart(start, opener);
    write(this);
    closeBlock(closer);
  }
}
