import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class ChefsTabPage extends StatefulWidget {
  const ChefsTabPage({super.key});

  @override
  State<ChefsTabPage> createState() => _ChefsTabPageState();
}

class _ChefsTabPageState extends State<ChefsTabPage> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Contenido Chefs'),
    );
  }
}
