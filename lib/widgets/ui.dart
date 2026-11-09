import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/theme.dart';

/// Piezas visuales compartidas del taller. Todas las pantallas usan las
/// mismas cajas, renglones, encabezados y cifras que Inicio, y los colores
/// salen de [AppColors] para que el modo oscuro funcione en todas.

/// Encabezado de sección: título a la izquierda y, opcional, una acción.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const SectionHeader(
    this.title, {
    super.key,
    this.action,
    this.onAction,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.navy,
              ),
            ),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.blue,
                minimumSize: const Size(44, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actionIcon != null) ...[
                    Icon(actionIcon, size: 18),
                    const SizedBox(width: 4),
                  ],
                  Text(action!, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Caja blanca (o carbón en modo oscuro) con borde fino.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Caja con renglones separados por líneas finas (como las listas de Inicio).
class ListBox extends StatelessWidget {
  final List<Widget> children;

  const ListBox({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(kRadius),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      // Material transparente: el efecto al tocar se ve sobre el fondo.
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
}

/// Renglón de una [ListBox]: ícono o avatar, título, subtítulo y algo a la
/// derecha (un monto, un estado o una flecha).
class BoxRow extends StatelessWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// El título va en monoespaciada (folios, montos).
  final bool monoTitle;

  const BoxRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.monoTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monoTitle
                        ? AppText.mono(fontSize: 14, color: AppColors.navy)
                        : TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.navy,
                          ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Ícono en un cuadro suave, para el inicio de un [BoxRow].
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final Color? background;

  const IconBadge(this.icon, {super.key, this.color, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: background ?? AppColors.lightBlue,
        borderRadius: BorderRadius.circular(kRadius),
      ),
      child: Icon(icon, size: 18, color: color ?? AppColors.navy),
    );
  }
}

/// Monto alineado a la derecha en monoespaciada.
class MoneyText extends StatelessWidget {
  final String text;
  final Color? color;
  final double fontSize;

  const MoneyText(this.text, {super.key, this.color, this.fontSize = 14});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: AppText.mono(fontSize: fontSize, color: color ?? AppColors.navy),
  );
}

/// Renglón "etiqueta ...... valor" para resúmenes de dinero.
class SummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool strong;

  const SummaryLine(
    this.label,
    this.value, {
    super.key,
    this.color,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: strong ? 15 : 13,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
                color: color ?? (strong ? AppColors.navy : AppColors.textMuted),
              ),
            ),
          ),
          Text(
            value,
            style: AppText.mono(
              fontSize: strong ? 17 : 14,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              color: color ?? AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}

/// Franja carbón con la cifra principal y, abajo, cifras secundarias
/// (la misma de "Saldo por cobrar" en Inicio).
class MetricPanel extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;
  final List<(String, String)> figures;
  final VoidCallback? onTap;

  const MetricPanel({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.figures = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(kRadius),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.carbon,
          borderRadius: BorderRadius.circular(kRadius),
          border: isDark ? Border.all(color: AppColors.borderDark) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.aluminum),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppText.mono(fontSize: 30, color: AppColors.textOnDark),
            ),
            if (caption != null) ...[
              const SizedBox(height: 2),
              Text(
                caption!,
                style: const TextStyle(fontSize: 13, color: AppColors.aluminum),
              ),
            ],
            if (figures.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.only(top: 12),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.borderDark)),
                ),
                child: Row(
                  children: [
                    for (int i = 0; i < figures.length; i++)
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : 12),
                          decoration: i == 0
                              ? null
                              : const BoxDecoration(
                                  border: Border(
                                    left: BorderSide(
                                      color: AppColors.borderDark,
                                    ),
                                  ),
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                figures[i].$1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.aluminum,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                figures[i].$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.mono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textOnDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila deslizable de filtros (Todas, Pendiente, ...).
class FilterBar extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option),
                selected: option == selected,
                showCheckmark: false,
                selectedColor: AppColors.navy,
                backgroundColor: AppColors.card,
                side: BorderSide(
                  color: option == selected
                      ? Colors.transparent
                      : AppColors.border,
                ),
                labelStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: option == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: option == selected ? AppColors.onInk : AppColors.navy,
                ),
                onSelected: (_) => onSelected(option),
              ),
            ),
        ],
      ),
    );
  }
}

/// Pantalla o sección vacía: ícono grande, mensaje y, opcional, un botón.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.lightBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: Text(actionLabel!),
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}

/// Encabezado de una hoja inferior: título y botón de cerrar.
class SheetHeader extends StatelessWidget {
  final String title;

  const SheetHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.navy,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
