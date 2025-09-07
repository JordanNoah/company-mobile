import 'package:auto_route/auto_route.dart';
import 'package:company/core/di.dart';
import 'package:company/routes.dart';
import 'package:flutter/material.dart';

@RoutePage()
class InitialPage extends StatefulWidget {
  const InitialPage({super.key});

  @override
  State<InitialPage> createState() => _InitialPageState();
}

class _InitialPageState extends State<InitialPage> {
  Future<bool>? _bootstrapOnce;

  @override
  void initState() {
    super.initState();
    _bootstrapOnce = http.bootstrapSession();     // 👈 corre 1 sola vez
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _bootstrapOnce,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        final hasSession =
            (http.accessToken != null && http.accessToken!.isNotEmpty) ||
            (snap.data == true);

        if (hasSession) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.router.replaceAll([const InsideRoute()]);
          });
          return const SizedBox.shrink();
        }

        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Bienvenido a Pleasure of world',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.router.push(LoginRoute()),
                  child: const Text('Logeate'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => context.router.push(SignUpRoute()),
                  child: const Text('Regístrate'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
