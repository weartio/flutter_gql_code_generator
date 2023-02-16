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
