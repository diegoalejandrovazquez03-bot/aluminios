import 'package:flutter/material.dart';

import '../core/app_navigation.dart';
import '../core/constants.dart';
import 'avatar_widget.dart';

class TopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showLogo;
  final Widget? leading;
  final List<Widget>? actions;
  final VoidCallback? onAvatarTap;

  /// A dónde regresa la flecha; por defecto, a la pantalla anterior.
  final VoidCallback? onBack;

  const TopBar({
    super.key,
    required this.title,
    this.showLogo = false,
    this.leading,
    this.actions,
    this.onAvatarTap,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textOnDark : AppColors.carbon;

    // Menú lateral a la izquierda; la flecha de regresar va a la derecha.
    return AppBar(
      leading:
          leading ??
          IconButton(
            tooltip: 'Menú',
            icon: Icon(Icons.menu, color: fg),
            onPressed: () => AppNavigation.openMenu?.call(),
          ),
      titleSpacing: 0,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLogo) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.asset(
                'assets/images/logo.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 28,
                  height: 28,
                  color: AppColors.carbon,
                  child: const Icon(
                    Icons.architecture,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: showLogo ? 15 : 17,
                letterSpacing: showLogo ? 3 : 0,
              ),
            ),
          ),
        ],
      ),
      actions: [
        ...?actions,
        if (onAvatarTap != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: onAvatarTap,
              child: const AvatarWidget(name: 'Usuario', size: 34),
            ),
          ),
        IconButton(
          tooltip: 'Volver',
          icon: Icon(Icons.arrow_back, color: fg),
          onPressed: onBack ?? AppNavigation.onBack,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
