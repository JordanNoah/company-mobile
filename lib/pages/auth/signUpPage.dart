import 'package:auto_route/auto_route.dart';
import 'package:company/components/custom_field.dart';
import 'package:company/components/password_field.dart';
import 'package:company/core/authStorage.dart';
import 'package:company/models/field_config.dart';
import 'package:company/routes.dart';
import 'package:company/service/http.dart';
import 'package:company/utils/rules.dart';
import 'package:company/service/external.dart';
import 'package:flutter/material.dart';

@RoutePage()
class SignUpPage extends StatefulWidget {
  const SignUpPage({Key? key}) : super(key: key);

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  Map<String, String?> _serverErrors = {};
  bool _triedSubmit = false;

  // Config de campos (const-friendly)
  final fields = <FieldConfig>[
    FieldConfig(
      name: 'idNumber',
      label: 'Número de identificación',
      icon: Icons.perm_identity,
      keyboard: TextInputType.number,
      digitsOnly: true,
      maxLength: 13,
      rules: [
        Rules.required('Este campo es obligatorio'),
        Rules.lengthIs(13, 'Debe tener 13 dígitos'),
      ],
    ),
    FieldConfig(
      name: 'businessName',
      label: 'Razón social',
      icon: Icons.domain,
      rules: [Rules.required('Este campo es obligatorio')],
    ),
    FieldConfig(
      name: 'tradeName',
      label: 'Nombre comercial',
      icon: Icons.storefront,
      rules: [Rules.required('Este campo es obligatorio')],
    ),
    FieldConfig(
      name: 'phone',
      label: 'Teléfono móvil',
      icon: Icons.smartphone,
      keyboard: TextInputType.phone,
      digitsOnly: true,
      maxLength: 10,
      rules: [Rules.required('Este campo es obligatorio')],
    ),
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

  // Un controller por campo + password
  late final List<TextEditingController> _ctrls = List.generate(
    fields.length,
    (_) => TextEditingController(),
  );
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool _loading = false;

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _triedSubmit = true;
      _serverErrors.clear();
    });

    try {
      final payload = {
        'idNumber': _ctrls[0].text.trim(),
        'businessName': _ctrls[1].text.trim(),
        'tradeName': _ctrls[2].text.trim(),
        'phone': _ctrls[3].text.trim(),
        'email': _ctrls[4].text.trim(),
        'password': _passwordCtrl.text,
      };

      final res = await signup(payload);

      if (!mounted) return;

      // 👇 Si tu API devuelve “ya existe” con 200, sigue como lo tienes
      if (res.status == 200) {
        setState(() {
          if (res.company.identificationNumber == payload['idNumber']) {
            _serverErrors['idNumber'] =
                'Ya existe una empresa con esa identificación';
          }
          if (res.company.email == payload['email']) {
            _serverErrors['email'] = 'El correo ya está registrado';
          }
          if (res.company.mobilePhone == payload['phone']) {
            _serverErrors['phone'] = 'Ese teléfono ya está en uso';
          }
          if (res.company.commercialName == payload['tradeName']) {
            _serverErrors['tradeName'] = 'El nombre comercial ya existe';
          }
          if (res.company.socialReason == payload['businessName']) {
            _serverErrors['businessName'] = 'La razón social ya existe';
          }
        });
        _formKey.currentState!.validate();
        return;
      }

      // ✅ Si signup crea la sesión y setea la cookie `rt`, refresca para obtener access token
      if (res.status == 201) {
        final accessToken = res.accessToken;
        final refreshToken = res.refreshToken;

        if (accessToken.isNotEmpty) {
          await AuthStorage.saveAccessToken(accessToken);
        }
        if (refreshToken.isNotEmpty) {
          await AuthStorage.saveRefreshToken(
            refreshToken,
          ); // crea este método si quieres persistirlo
        }
        final company = res.company; // tipo Company (o Map, según tu modelo)
        final companyId = company.id.toString();
        if (companyId.isNotEmpty) {
          await AuthStorage.saveCompanyId(companyId);
        }
        // Si quieres tener todo el objeto disponible luego:
        try {
          // Si `company` es clase, conviértela a Map (p.ej. company.toJson()).
          // si ya es Map, guárdalo directo:
          await AuthStorage.saveCompanyJson((res.company).toJson());
        } catch (_) {}
        if (!mounted) return;
        context.router.replaceAll([const InsideRoute()]);
      }
    } catch (e) {
      if (!mounted) return;
      // Muestra error global si quieres
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrar. Intenta nuevamente.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height,
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Vamos a empezar',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 20),

                  for (var i = 0; i < fields.length; i++) ...[
                    CustomTextField(
                      config: fields[i],
                      controller: _ctrls[i],
                      serverError: _serverErrors[fields[i].name],
                      alwaysValidate: _triedSubmit || _serverErrors.isNotEmpty,
                      onChanged: (_) {
                        if (_serverErrors[fields[i].name] != null) {
                          setState(() => _serverErrors[fields[i].name] = null);
                        }
                      },
                    ),
                    const SizedBox(height: 20),
                  ],

                  PasswordField(
                    controller: _passwordCtrl,
                    label: 'Contraseña',
                    rules: [
                      Rules.required('Este campo es obligatorio'),
                      Rules.minLength(
                        8,
                        'La contraseña debe tener al menos 8 caracteres',
                      ),
                      Rules.password(
                        'La contraseña debe contener al menos una letra y un número',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: _loading ? null : _submit,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Crear cuenta'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
