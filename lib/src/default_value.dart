import 'code_writer.dart';
import 'generator.dart';
import 'member_type.dart';
import 'string_extensions.dart';

abstract class DefaultValue {
  void writeTo(Generator generator, CodeWriter writer);
}

class IntDefaultValue implements DefaultValue {
  const IntDefaultValue(this.value);
  final int value;
  @override
  void writeTo(Generator generator, CodeWriter writer) {
    writer.write('$value');
  }
}

class StringDefaultValue implements DefaultValue {
  const StringDefaultValue(this.value);
  final String value;
  @override
  void writeTo(Generator generator, CodeWriter writer) {
    writer.write("'${value.escapeText()}'");
  }
}

class FloatDefaultValue implements DefaultValue {
  const FloatDefaultValue(this.value);
  final double value;
  @override
  void writeTo(Generator generator, CodeWriter writer) {
    writer.write('$value');
  }
}

class EnumDefaultValue implements DefaultValue {
  const EnumDefaultValue({
    required this.enumType,
    required this.enumValue,
  });
  final String enumValue;
  final String enumType;

  @override
  void writeTo(Generator generator, CodeWriter writer) {
    final enumTypeName = generator.fixName(
      enumType,
      MemberType.enumeration,
    );
    final enumValueName = generator.fixName(
      enumValue,
      MemberType.field,
    );
    writer.write('$enumTypeName.$enumValueName');
  }
}

class NullDefaultValue implements DefaultValue {
  @override
  void writeTo(Generator generator, CodeWriter writer) {}
}

class BooleanDefaultValue implements DefaultValue {
  const BooleanDefaultValue(this.value);
  final bool value;
  @override
  void writeTo(Generator generator, CodeWriter writer) {
    writer.write(value ? 'true' : 'false');
  }
}
