import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class BranchesTabPage extends StatefulWidget {
  const BranchesTabPage({super.key});

  @override
  State<BranchesTabPage> createState() => _BranchesTabPageState();
}

class _BranchesTabPageState extends State<BranchesTabPage> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Contenido Sucursales'),
    );
  }
}