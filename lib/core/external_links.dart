import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre llamadas, WhatsApp u otros enlaces externos.
/// No usa canLaunchUrl: en Android 11+ devuelve false aunque la app exista
/// si el paquete no está declarado en `<queries>`. Se intenta abrir directo
/// y, si falla, se avisa al usuario.
class ExternalLinks {
  static String _digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');

  static Future<void> call(BuildContext context, String phone) => _open(
    context,
    Uri.parse('tel:${_digits(phone)}'),
    'Este dispositivo no puede iniciar llamadas.',
  );

  static Future<void> whatsApp(
    BuildContext context,
    String phone, {
    String message = '',
  }) {
    final text = message.isEmpty ? '' : '?text=${Uri.encodeComponent(message)}';
    return _open(
      context,
      Uri.parse('https://wa.me/52${_digits(phone)}$text'),
      'No se pudo abrir WhatsApp.',
    );
  }

  static Future<void> _open(BuildContext context, Uri url, String error) async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!opened) messenger.showSnackBar(SnackBar(content: Text(error)));
  }
}
