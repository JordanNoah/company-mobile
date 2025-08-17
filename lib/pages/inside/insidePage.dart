import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

// importa tus páginas reales
import 'configurationPage.dart';
import 'homePage.dart';
import 'postPage.dart';
import 'stadisticPage.dart';

@RoutePage()
class InsidePage extends StatefulWidget {
  const InsidePage({super.key});

  @override
  State<InsidePage> createState() => _InsidePageState();
}

class _InsidePageState extends State<InsidePage> {
  final controller = Get.put(NavigationController(), permanent: true);

  final _pages = const <Widget>[
    HomePage(),
    PostPage(),
    StadisticPage(),
    ConfigurationPage(),
  ];

  final _titles = const ['Inicio','Posts','Estadísticas','Ajustes'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_titles[controller.selectedIndex.value])),
      ),
      body: Obx(() => IndexedStack(
            index: controller.selectedIndex.value,
            children: _pages,
          )),
      bottomNavigationBar: Obx(() => NavigationBar(
            height: 60,
            elevation: 0,
            selectedIndex: controller.selectedIndex.value,
            onDestinationSelected: controller.changeIndex,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
              NavigationDestination(icon: Icon(Icons.post_add), label: 'Posts'),
              NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
            ],
          )),
    );
  }
}

class NavigationController extends GetxController {
  var selectedIndex = 0.obs;
  void changeIndex(int i) => selectedIndex.value = i;
}