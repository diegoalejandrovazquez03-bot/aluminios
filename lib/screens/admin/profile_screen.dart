import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../state/app_state.dart';
import '../../widgets/avatar_widget.dart';
import '../../widgets/profile_photo_options.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/ui.dart';

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
            const SheetHeader('Información del negocio'),
            const SizedBox(height: 6),
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
              const SheetHeader('Configuración del sistema'),
              const SizedBox(height: 8),
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
    return Scaffold(
      appBar: TopBar(title: 'Mi Perfil'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Profile Header
          Center(
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => showProfilePhotoOptions(
                    context,
                    currentUrl: state.settings.avatarUrl,
                    onSave: (url) => state.updateSettings(
                      state.settings.copyWith(avatarUrl: url),
                    ),
                  ),
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
                    color: AppColors.navy,
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

          ListBox(
            children: [
              BoxRow(
                leading: const IconBadge(Icons.store_mall_directory_outlined),
                title: 'Información del negocio',
                trailing: _chevron,
                onTap: () => _openBizModal(context),
              ),
              BoxRow(
                leading: const IconBadge(Icons.dark_mode_outlined),
                title: 'Modo oscuro',
                trailing: Switch.adaptive(
                  value: state.settings.dark,
                  activeTrackColor: AppColors.navy,
                  onChanged: (val) => state.toggleDarkMode(val),
                ),
                onTap: () => state.toggleDarkMode(!state.settings.dark),
              ),
              BoxRow(
                leading: const IconBadge(Icons.settings_outlined),
                title: 'Configuración del sistema',
                trailing: _chevron,
                onTap: () => _openConfigModal(context),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cerrar sesión: en rojo y aparte de las demás opciones.
          ListBox(
            children: [
              BoxRow(
                leading: IconBadge(
                  Icons.logout,
                  color: AppColors.cancelled,
                  background: AppColors.cancelledBg,
                ),
                title: 'Cerrar sesión',
                trailing: _chevron,
                onTap: () => _confirmLogout(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget get _chevron => Icon(Icons.chevron_right, color: AppColors.textMuted);
}
