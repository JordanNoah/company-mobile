import 'package:auto_route/auto_route.dart';
import 'package:company/pages/auth/initialPage.dart';
import 'package:company/pages/auth/loginPage.dart';
import 'package:company/pages/auth/signUpPage.dart';
import 'package:company/pages/inside/configurationPage.dart';
import 'package:company/pages/inside/homePage.dart';
import 'package:company/pages/inside/insidePage.dart';
import 'package:company/pages/inside/postPage.dart';
import 'package:company/pages/inside/stadisticPage.dart';

part 'routes.gr.dart';

@AutoRouterConfig(replaceInRouteName: 'Page,Route')
class AppRouter extends RootStackRouter {
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      page: InitialRoute.page,
      initial: true,
    ),
    AutoRoute(page: SignUpRoute.page),
    AutoRoute(page: LoginRoute.page),
    AutoRoute(page: InsideRoute.page),
  ];
}