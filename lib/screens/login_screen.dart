import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  final AppState state;

  const LoginScreen({super.key, required this.state});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegister = false;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String? _errorMsg;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _errorMsg = null);

    if (_isRegister) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _errorMsg = 'Ingresa tu nombre completo');
        return;
      }
      if (_phoneCtrl.text.trim().length < 10) {
        setState(() => _errorMsg = 'Ingresa un teléfono válido de 10 dígitos');
        return;
      }
      final err = widget.state.register(
        _nameCtrl.text,
        _phoneCtrl.text,
        _emailCtrl.text,
        _passCtrl.text,
      );
      if (err != null) setState(() => _errorMsg = err);
    } else {
      final err = widget.state.login(_emailCtrl.text, _passCtrl.text);
      if (err != null) setState(() => _errorMsg = err);
    }
  }

  void _setMode(bool register) {
    setState(() {
      _isRegister = register;
      _errorMsg = null;
    });
  }

  // El login siempre se muestra en carbón para que luzca el logo cromado.
  InputDecoration _field(String label, {Widget? suffix}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(kRadius),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.mutedOnDark, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: AppColors.textOnDark),
      filled: true,
      fillColor: AppColors.surfaceDark,
      suffixIcon: suffix,
      suffixIconColor: AppColors.mutedOnDark,
      border: border(AppColors.borderDark),
      enabledBorder: border(AppColors.borderDark),
      focusedBorder: border(AppColors.textOnDark, 1.5),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.textOnDark : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.textOnDark : AppColors.mutedOnDark,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const inputText = TextStyle(color: AppColors.textOnDark, fontSize: 15);

    return Scaffold(
      backgroundColor: AppColors.bgDark,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 112,
                          height: 112,
                          color: Colors.black,
                          child: const Icon(
                            Icons.architecture_rounded,
                            color: AppColors.aluminum,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'ALUMINIOS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 22,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister
                        ? 'Crea tu cuenta de cliente'
                        : 'Cancelería, aluminio y vidrio',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.mutedOnDark,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 40),

                  Container(
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderDark),
                      ),
                    ),
                    child: Row(
                      children: [
                        _tab(
                          'Iniciar sesión',
                          !_isRegister,
                          () => _setMode(false),
                        ),
                        const SizedBox(width: 24),
                        _tab('Crear cuenta', _isRegister, () => _setMode(true)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_isRegister) ...[
                    TextField(
                      controller: _nameCtrl,
                      style: inputText,
                      cursorColor: AppColors.textOnDark,
                      decoration: _field('Nombre completo'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: inputText,
                      cursorColor: AppColors.textOnDark,
                      decoration: _field('Teléfono (10 dígitos)'),
                    ),
                    const SizedBox(height: 16),
                  ],

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: inputText,
                    cursorColor: AppColors.textOnDark,
                    decoration: _field('Correo electrónico'),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: _passCtrl,
                    obscureText: _obscurePassword,
                    style: inputText,
                    cursorColor: AppColors.textOnDark,
                    onSubmitted: (_) => _submit(),
                    decoration: _field(
                      'Contraseña',
                      suffix: IconButton(
                        tooltip: _obscurePassword
                            ? 'Mostrar contraseña'
                            : 'Ocultar contraseña',
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(kRadius),
                        border: Border.all(color: const Color(0xFF7A3A32)),
                      ),
                      child: Text(
                        _errorMsg!,
                        style: const TextStyle(
                          color: Color(0xFFF0B4AA),
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textOnDark,
                      foregroundColor: AppColors.bgDark,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _submit,
                    child: Text(_isRegister ? 'Crear cuenta' : 'Ingresar'),
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
