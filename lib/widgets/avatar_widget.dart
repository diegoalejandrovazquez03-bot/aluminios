import 'package:flutter/material.dart';

import '../core/constants.dart';
import 'app_image.dart';

class AvatarWidget extends StatelessWidget {
  final String name;
  final double size;
  final String? imageUrl;

  const AvatarWidget({
    super.key,
    required this.name,
    this.size = 40,
    this.imageUrl,
  });

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return "${parts[0][0]}${parts[1][0]}".toUpperCase();
  }

  Color _colorFor(String n) {
    if (n.isEmpty) return AppColors.avatarColors[0];
    final code = n.codeUnitAt(0) + n.length;
    return AppColors.avatarColors[code % AppColors.avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: AppImage(
          imageUrl!,
          width: size,
          height: size,
          fallback: _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _colorFor(name), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}
