import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class StadisticPage extends StatefulWidget {
  const StadisticPage({super.key});

  @override
  State<StadisticPage> createState() => _StadisticPageState();
}

class _StadisticPageState extends State<StadisticPage> {
  @override
  Widget build(BuildContext context) {
    return Center(child: Text('This is the Stadistic Page'));
  }
}