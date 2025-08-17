import 'package:auto_route/auto_route.dart';
import 'package:company/components/custom_field.dart';
import 'package:company/components/password_field.dart';
import 'package:company/core/authStorage.dart';
import 'package:company/models/field_config.dart';
import 'package:company/routes.dart';
import 'package:company/service/external.dart';
import 'package:flutter/material.dart';
import 'package:company/utils/rules.dart';

@RoutePage()
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  // Campo(s) configurados
  final fields = <FieldConfig>[
    FieldConfig(
      name: 'email',
      label: 'Correo electrónico',
      icon: Icons.alternate_email,
      keyboard: TextInputType.emailAddress,
      rules: [
        Rules.required('Este campo es obligatorio'),
        Rules.email('Formato de correo inválido'),
      ],
    ),
  ];

  // Controllers
  late final List<TextEditingController> _ctrls = List.generate(
    fields.length,
    (_) => TextEditingController(),
  );
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  String? _errorMsg;

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final payload = {
      'email': _ctrls[0].text.trim(),
      'password': _passwordCtrl.text,
    };

    try {
      final res = await login(payload);
      if (!mounted) return;

      // Credenciales inválidas
      if (res.status == 401) {
        setState(() {
          _errorMsg = 'Correo o contraseña inválidos';
        });
        return;
      }

      // Éxito: el back retorna accessToken y refreshToken en el body
      if (res.status == 200 || res.status == 201) {
        final at = (res.accessToken ?? '').toString();
        final rt = (res.refreshToken ?? '').toString();

        if (at.isEmpty) {
          setState(() {
            _errorMsg = 'No se recibió accessToken del servidor';
          });
          return;
        }

        // Guarda tokens
        await AuthStorage.saveAccessToken(at);
        if (rt.isNotEmpty) {
          await AuthStorage.saveRefreshToken(rt);
        }

        if (!mounted) return;
        context.router.replaceAll([const InsideRoute()]);
        return;
      }

      // Otros códigos
      setState(() {
        _errorMsg = 'Error inesperado. Intenta nuevamente.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Error de red o del servidor';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Inicia sesión para continuar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),

                // Email
                CustomTextField(config: fields[0], controller: _ctrls[0]),
                const SizedBox(height: 20),

                // Password reutilizable con validator
                PasswordField(
                  controller: _passwordCtrl,
                  label: 'Contraseña',
                  rules: [Rules.required('Este campo es obligatorio')],
                ),
                const SizedBox(height: 20),

                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const CircularProgressIndicator()
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 12),
                if (_errorMsg != null)
                  Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
                // Ir a registro
                TextButton(
                  onPressed: () => context.router.push(const SignUpRoute()),
                  child: const Text('¿No tienes una cuenta? Regístrate'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
