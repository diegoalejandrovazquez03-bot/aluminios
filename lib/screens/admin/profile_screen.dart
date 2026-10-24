import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/top_bar.dart';

class ProfileScreen extends StatelessWidget {
  final AppState state;
  final Function(int) onNavigate;

  const ProfileScreen({
    super.key,
    required this.state,
    required this.onNavigate,
  });

  void _openBizModal(BuildContext context) {
    final nameCtrl = TextEditingController(text: state.settings.bizName);
    final phoneCtrl = TextEditingController(text: state.settings.bizPhone);
    final addrCtrl = TextEditingController(text: state.settings.bizAddress);
    final descriptionCtrl = TextEditingController(
      text: state.settings.profileDescription,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Información del Negocio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre comercial'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono de contacto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addrCtrl,
              decoration: const InputDecoration(
                labelText: 'Dirección física / Taller',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripción del perfil',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                state.updateSettings(
                  state.settings.copyWith(
                    bizName: nameCtrl.text.trim(),
                    bizPhone: phoneCtrl.text.trim(),
                    bizAddress: addrCtrl.text.trim(),
                    profileDescription: descriptionCtrl.text.trim(),
                  ),
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Información actualizada')),
                );
              },
              child: const Text('Guardar Cambios'),
            ),
          ],
        ),
      ),
    );
  }

  void _openConfigModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Configuración del Sistema',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                title: const Text(
                  'Asesor de cotización',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Sugerencias automáticas y chat técnico',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                value: state.settings.ai,
                activeTrackColor: AppColors.navy,
                onChanged: (val) {
                  state.updateSettings(state.settings.copyWith(ai: val));
                  setModalState(() {});
                },
              ),
              SwitchListTile.adaptive(
                title: const Text(
                  'Notificaciones push',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Avisos de pedidos pendientes y recordatorios',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                value: state.settings.notifications,
                activeTrackColor: AppColors.navy,
                onChanged: (val) {
                  state.updateSettings(
                    state.settings.copyWith(notifications: val),
                  );
                  setModalState(() {});
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Restaurar datos de demostración'),
                onPressed: () {
                  state.resetData();
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Datos de demostración restaurados'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Se cerrará la sesión actual en este dispositivo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.cancelled,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
            },
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: TopBar(
        title: 'Mi Perfil',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => onNavigate(0),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () async {
                    try {
                      final photo = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 65,
                        maxWidth: 1200,
                        maxHeight: 1200,
                      );
                      if (photo != null) {
                        final bytes = await photo.readAsBytes();
                        state.updateSettings(
                          state.settings.copyWith(
                            avatarUrl:
                                'data:image/jpeg;base64,${base64Encode(bytes)}',
                          ),
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'No se pudo abrir la galería. Revisa los permisos.',
                          ),
                        ),
                      );
                    }
                  },
                  child: AvatarWidget(
                    name: 'Juan Pérez',
                    size: 76,
                    imageUrl: state.settings.avatarUrl,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Juan Pérez',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : AppColors.navy,
                  ),
                ),
                Text(
                  'Propietario • ${state.settings.bizName}',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                if (state.settings.profileDescription.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    state.settings.profileDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Options List
          _menuTile(
            icon: Icons.store_mall_directory_outlined,
            title: 'Información del negocio',
            onTap: () => _openBizModal(context),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.dark_mode_outlined,
            title: 'Modo oscuro',
            onTap: () => state.toggleDarkMode(!state.settings.dark),
            trailing: Switch.adaptive(
              value: state.settings.dark,
              activeTrackColor: AppColors.navy,
              onChanged: (val) => state.toggleDarkMode(val),
            ),
            isDark: isDark,
          ),
          _menuTile(
            icon: Icons.settings_outlined,
            title: 'Configuración del sistema',
            onTap: () => _openConfigModal(context),
            isDark: isDark,
          ),
          const SizedBox(height: 14),

          // Logout
          Container(
            decoration: BoxDecoration(
              color: AppColors.cancelledBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.cancelledBg),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                leading: Icon(Icons.logout, color: AppColors.cancelled),
                title: Text(
                  'Cerrar sesión',
                  style: TextStyle(
                    color: AppColors.cancelled,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Icon(Icons.chevron_right, color: AppColors.cancelled),
                onTap: () => _confirmLogout(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Widget? trailing,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: AppColors.navy, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : AppColors.navy,
            ),
          ),
          trailing:
              trailing ?? Icon(Icons.chevron_right, color: AppColors.textMuted),
          onTap: onTap,
        ),
      ),
    );
  }
}
