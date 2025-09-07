import 'package:auto_route/auto_route.dart';

// Auth
import 'package:company/pages/auth/initialPage.dart';
import 'package:company/pages/auth/loginPage.dart';
import 'package:company/pages/auth/signUpPage.dart';

// Inside
import 'package:company/pages/inside/insidePage.dart';
import 'package:company/pages/inside/home/homePage.dart';           // 👈 nuevo path
import 'package:company/pages/inside/postPage.dart';
import 'package:company/pages/inside/stadisticPage.dart';
import 'package:company/pages/inside/configurationPage.dart';
import 'package:company/pages/inside/home/sections/branches_tab.dart';
import 'package:company/pages/inside/home/sections/chefs_tab.dart';
import 'package:company/pages/inside/home/sections/restaurant_tab.dart';

part 'routes.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
        // Arranque / Auth
        AutoRoute(page: InitialRoute.page, initial: true),
        AutoRoute(page: SignUpRoute.page),
        AutoRoute(page: LoginRoute.page),

        // Área privada
        AutoRoute(
          page: InsideRoute.page,
          path: '/inside',
          children: [
            // Home (contiene tus tabs internos, no son rutas)
            AutoRoute(page: HomeRoute.page, path: 'home', initial: true),

            // Otras pantallas internas (opcionales)
            AutoRoute(page: PostRoute.page, path: 'posts'),
            AutoRoute(page: StadisticRoute.page, path: 'stats'),
            AutoRoute(page: ConfigurationRoute.page, path: 'config'),
          ],
        ),
      ];
}
