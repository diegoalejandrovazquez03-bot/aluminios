import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/external_links.dart';
import '../../core/input_rules.dart';
import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/profile_photo_options.dart';
import '../../widgets/sheet_message.dart';
import '../../widgets/top_bar.dart';

/// Perfil del cliente: sus datos, su foto, su contraseña y preferencias.
/// No incluye nada de la configuración del taller (eso es solo del dueño).
class ClientProfileScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ClientProfileScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final account = state.currentAccount;
    final client = state.currentClient;
    final name = account?.name ?? client?.name ?? 'Cliente';
    final phone = account?.phone ?? client?.phone ?? '';
    final email = account?.email ?? state.session?.email ?? '';

    return Scaffold(
      appBar: const TopBar(title: 'Mi perfil'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
        children: [
          Center(
            child: Column(
              children: [
                Semantics(
                  button: true,
                  label: 'Cambiar foto de perfil',
                  child: GestureDetector(
                    onTap: account == null
                        ? null
                        : () => showProfilePhotoOptions(
                            context,
                            currentUrl: account.avatarUrl,
                            onSave: state.updateMyAvatar,
                          ),
                    child: Stack(
                      children: [
                        AvatarWidget(
                          name: name,
                          size: 88,
                          imageUrl: account?.avatarUrl,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.navy,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.card,
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.photo_camera_outlined,
                              size: 14,
                              color: AppColors.onInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email.isEmpty ? 'Cuenta de cliente' : email,
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          _sectionTitle('MIS DATOS'),
          _box([
            _infoRow('Nombre', name),
            _infoRow('Teléfono', phone.isEmpty ? '—' : phone, mono: true),
            _infoRow('Correo', email.isEmpty ? '—' : email),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Editar mis datos'),
            onPressed: account == null
                ? null
                : () => _openEditData(context, name, phone, email),
          ),
          const SizedBox(height: 24),

          _sectionTitle('SEGURIDAD Y PREFERENCIAS'),
          _box([
            _actionRow(
              icon: Icons.lock_outline,
              title: 'Cambiar contraseña',
              onTap: account == null ? null : () => _openPassword(context),
            ),
            SwitchListTile.adaptive(
              secondary: Icon(Icons.dark_mode_outlined, color: AppColors.navy),
              title: Text(
                'Modo oscuro',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.navy,
                ),
              ),
              value: state.settings.dark,
              onChanged: state.toggleDarkMode,
            ),
          ]),
          const SizedBox(height: 24),

          _sectionTitle('CONTACTO DEL TALLER'),
          _box([
            _infoRow('Taller', state.settings.bizName),
            if (state.settings.bizPhone.isNotEmpty)
              _infoRow('Teléfono', state.settings.bizPhone, mono: true),
          ]),
          if (state.settings.bizPhone.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.phone_outlined, size: 18),
                    label: const Text('Llamar'),
                    onPressed: () =>
                        ExternalLinks.call(context, state.settings.bizPhone),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('WhatsApp'),
                    onPressed: () => ExternalLinks.whatsApp(
                      context,
                      state.settings.bizPhone,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 32),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.cancelled,
              side: BorderSide(color: AppColors.cancelled),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Cerrar sesión'),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(text, style: AppText.label(color: AppColors.textMuted)),
  );

  Widget _box(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // Material propio: así el efecto al tocar los renglones se ve sobre el fondo.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: AppColors.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 82,
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? AppText.mono(fontSize: 14, color: AppColors.navy)
                  : TextStyle(fontSize: 14, color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.navy),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.navy,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: AppColors.textMuted),
      onTap: onTap,
    );
  }

  /// Hoja para editar nombre, teléfono y correo.
  void _openEditData(
    BuildContext context,
    String name,
    String phone,
    String email,
  ) {
    final nameCtrl = TextEditingController(text: name);
    final phoneCtrl = TextEditingController(
      text: phone.replaceAll(RegExp(r'\D'), ''),
    );
    final emailCtrl = TextEditingController(text: email);
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => _sheet(
          ctx,
          title: 'Editar mis datos',
          children: [
            TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: PhoneInput.formatters,
              decoration: InputDecoration(
                labelText: 'Teléfono (10 dígitos)',
                counterText: '${phoneCtrl.text.length}/10',
              ),
              onChanged: (_) => setSheetState(() {}),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      setSheetState(() => saving = true);
                      final error = await state.updateMyProfile(
                        name: nameCtrl.text,
                        phone: phoneCtrl.text,
                        email: emailCtrl.text,
                      );
                      if (!ctx.mounted) return;
                      setSheetState(() => saving = false);
                      if (error != null) {
                        showSheetMessage(ctx, error);
                        return;
                      }
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Datos actualizados')),
                      );
                    },
              child: Text(saving ? 'Guardando…' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }

  /// Hoja para cambiar la contraseña (pide la actual y la nueva dos veces).
  void _openPassword(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obscure = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          InputDecoration deco(String label) => InputDecoration(
            labelText: label,
            suffixIcon: IconButton(
              tooltip: obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
              ),
              onPressed: () => setSheetState(() => obscure = !obscure),
            ),
          );
          return _sheet(
            ctx,
            title: 'Cambiar contraseña',
            children: [
              TextField(
                controller: currentCtrl,
                obscureText: obscure,
                decoration: deco('Contraseña actual'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newCtrl,
                obscureText: obscure,
                decoration: deco(
                  'Nueva contraseña (mín. ${AccountInput.minPassword} caracteres)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: obscure,
                decoration: deco('Confirmar nueva contraseña'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (newCtrl.text != confirmCtrl.text) {
                          showSheetMessage(
                            ctx,
                            'Las contraseñas nuevas no coinciden',
                          );
                          return;
                        }
                        final messenger = ScaffoldMessenger.of(context);
                        setSheetState(() => saving = true);
                        final error = await state.changeMyPassword(
                          currentCtrl.text,
                          newCtrl.text,
                        );
                        if (!ctx.mounted) return;
                        setSheetState(() => saving = false);
                        if (error != null) {
                          showSheetMessage(ctx, error);
                          return;
                        }
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Contraseña actualizada'),
                          ),
                        );
                      },
                child: Text(saving ? 'Guardando…' : 'Guardar contraseña'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sheet(
    BuildContext ctx, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que escribir tu correo y contraseña para volver a entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (ok == true) state.logout();
  }
}
