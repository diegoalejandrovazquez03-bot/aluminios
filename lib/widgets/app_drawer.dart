import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../state/app_state.dart';
import 'avatar_widget.dart';

class AppDrawer extends StatelessWidget {
  final AppState state;
  final int currentIndex;
  final Function(int) onSelectScreen;

  const AppDrawer({
    super.key,
    required this.state,
    required this.currentIndex,
    required this.onSelectScreen,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = state.isAdmin;

    final adminItems = [
      {'title': 'Inicio', 'icon': Icons.home_rounded, 'idx': 0},
      {'title': 'Productos', 'icon': Icons.inventory_2_rounded, 'idx': 1},
      {'title': 'Nueva cotización', 'icon': Icons.note_add_rounded, 'idx': 2},
      {'title': 'Cotizaciones', 'icon': Icons.receipt_long_rounded, 'idx': 3},
      {'title': 'Clientes', 'icon': Icons.people_alt_rounded, 'idx': 4},
      {
        'title': 'Anticipos y pagos',
        'icon': Icons.attach_money_rounded,
        'idx': 5,
      },
      {
        'title': 'Agenda de visitas',
        'icon': Icons.calendar_month_rounded,
        'idx': 6,
      },
      {
        'title': 'Catálogo visual',
        'icon': Icons.photo_library_rounded,
        'idx': 7,
      },
      {'title': 'Mi perfil', 'icon': Icons.person_rounded, 'idx': 8},
    ];

    final clientItems = [
      {'title': 'Inicio', 'icon': Icons.home_rounded, 'idx': 0},
      {'title': 'Catálogo', 'icon': Icons.inventory_2_rounded, 'idx': 1},
      {'title': 'Mis pedidos', 'icon': Icons.receipt_long_rounded, 'idx': 2},
      {'title': 'Mi perfil', 'icon': Icons.person_rounded, 'idx': 3},
    ];

    final items = isAdmin ? adminItems : clientItems;

    return Drawer(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  if (isAdmin)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 44,
                          height: 44,
                          color: AppColors.navy,
                          child: Icon(
                            Icons.architecture,
                            color: AppColors.onInk,
                          ),
                        ),
                      ),
                    )
                  else
                    AvatarWidget(
                      name: state.currentClient?.name ?? 'Cliente',
                      size: 44,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAdmin
                              ? 'ALUMINIOS'
                              : (state.currentClient?.name ?? 'Cliente'),
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          isAdmin
                              ? state.settings.bizName
                              : 'Cuenta de cliente',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.lightBlue),

            // Nav List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final it = items[i];
                  final isSelected = currentIndex == it['idx'];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      tileColor: isSelected
                          ? (isDark
                                ? AppColors.borderDark
                                : AppColors.lightBlue)
                          : null,
                      leading: Icon(
                        it['icon'] as IconData,
                        color: isSelected
                            ? AppColors.blue
                            : (isDark ? Colors.white70 : AppColors.navy),
                        size: 22,
                      ),
                      title: Text(
                        it['title'] as String,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.blue
                              : (isDark ? Colors.white : AppColors.navy),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context); // close drawer
                        onSelectScreen(it['idx'] as int);
                      },
                    ),
                  );
                },
              ),
            ),

            Divider(height: 1, color: AppColors.lightBlue),

            // Footer controls: Dark Mode & Logout
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dark_mode_outlined,
                        color: isDark ? Colors.white70 : AppColors.navy,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Modo oscuro',
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.navy,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        value: state.settings.dark,
                        activeTrackColor: AppColors.navy,
                        onChanged: (val) => state.toggleDarkMode(val),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cancelled,
                        side: BorderSide(color: AppColors.cancelledBg),
                        backgroundColor: AppColors.cancelledBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: const Text(
                        'Cerrar sesión',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        state.logout();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
