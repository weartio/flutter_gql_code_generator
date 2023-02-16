import 'fragment_def.dart';

class FragmentFile {
  FragmentFile({
    required this.defs,
    required this.refMap,
  });

  final List<FragmentDef> defs;
  final Map<String, List<String>> refMap;
}
