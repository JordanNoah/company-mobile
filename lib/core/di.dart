import 'package:company/service/http.dart';

final http = Http();                 // <-- única instancia

Future<void> initAppDependencies() async {
  await http.init();   
  await http.normalizeRtCookiePath();
}
