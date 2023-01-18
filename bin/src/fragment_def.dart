class FragmentDef {
  FragmentDef({
    required this.fragmentAlias,
    required this.fragmentRefs,
    required this.fragmentBody,
  });

  final List<String> fragmentRefs;
  final String fragmentAlias;
  final String fragmentBody;
}
