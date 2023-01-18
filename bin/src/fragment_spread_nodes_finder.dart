import 'package:gql/ast.dart' as gql;

class FragmentSpreadNodeFinder extends gql.RecursiveVisitor {
  final List<gql.FragmentSpreadNode> nodes = [];
  @override
  void visitFragmentSpreadNode(gql.FragmentSpreadNode node) {
    super.visitFragmentSpreadNode(node);
    nodes.add(node);
  }
}
