import 'package:auto_route/auto_route.dart';
import 'package:company/pages/inside/home/sections/chefs_tab.dart';
import 'package:flutter/material.dart';

// 👇 importa tus tabs (ubicados en lib/pages/inside/home/sections/)
import 'package:company/pages/inside/home/sections/restaurant_tab.dart';
import 'package:company/pages/inside/home/sections/branches_tab.dart';

@RoutePage()
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: Colors.transparent,
              child: const TabBar(
                indicatorColor: Colors.blue,
                labelColor: Colors.blue,
                unselectedLabelColor: Colors.grey,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'Restaurante'),
                  Tab(text: 'Sucursales'),
                  Tab(text: 'Chef'),
                ],
              ),
            ),

            const Expanded(
              child: TabBarView(
                children: [
                  RestaurantTabPage(),
                  BranchesTabPage(),
                  ChefsTabPage(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
