import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../state/app_state.dart';

/// Aviso de privacidad (LFPDPPP). Usa los datos del negocio de la
/// configuración.
///
/// IMPORTANTE: es un texto base. El negocio debe revisarlo (idealmente con un
/// abogado) y ajustarlo a su caso antes de publicar la app.
class PrivacyScreen extends StatelessWidget {
  final AppState state;

  const PrivacyScreen({super.key, required this.state});

  /// Abre el aviso como pantalla completa.
  static void open(BuildContext context, AppState state) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PrivacyScreen(state: state)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = state.settings;
    final contact = [
      if (s.bizPhone.isNotEmpty) 'teléfono ${s.bizPhone}',
      if (s.bizAddress.isNotEmpty) 'domicilio ${s.bizAddress}',
    ].join(' y ');
    final sections = <(String, String)>[
      (
        'Responsable',
        '${s.bizName} es responsable del tratamiento de tus datos personales'
            '${contact.isEmpty ? '' : ', con $contact'}.',
      ),
      (
        'Datos que recabamos',
        'Nombre, teléfono, correo electrónico, dirección de la obra o '
            'domicilio, fotografía de perfil (opcional), medidas y fotos de '
            'las piezas, cotizaciones, pagos y visitas agendadas.',
      ),
      (
        'Para qué los usamos',
        'Elaborar y enviarte cotizaciones, agendar visitas de medición e '
            'instalación, darte seguimiento a tus pedidos y pagos, y '
            'contactarte sobre ellos por teléfono o WhatsApp. No usamos tus '
            'datos para publicidad.',
      ),
      (
        'Con quién los compartimos',
        'No vendemos ni compartimos tus datos con terceros, salvo cuando lo '
            'exija una autoridad. Se guardan en los servidores que usa el '
            'taller para operar la aplicación.',
      ),
      (
        'Tus derechos (ARCO)',
        'Puedes acceder a tus datos, corregirlos, cancelarlos u oponerte a su '
            'uso. Puedes corregirlos en Perfil › Editar mis datos y eliminar '
            'tu cuenta en Perfil › Eliminar mi cuenta. Para cualquier otra '
            'solicitud, comunícate con el taller'
            '${s.bizPhone.isEmpty ? '' : ' al ${s.bizPhone}'}.',
      ),
      (
        'Conservación',
        'Al eliminar tu cuenta borramos tu cuenta, tu ficha de cliente y tus '
            'visitas. Las cotizaciones y pagos se conservan sin tu ficha '
            'personal, como registro comercial del taller, durante el tiempo '
            'que exija la ley.',
      ),
      (
        'Cambios a este aviso',
        'Cualquier cambio se publicará en esta misma sección de la aplicación.',
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Aviso de privacidad')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          for (final (title, body) in sections) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
