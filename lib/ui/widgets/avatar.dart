import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _palettes = [
  [Color(0xFFFF6AD5), Color(0xFF7F5AF0)],
  [Color(0xFF2CB1FF), Color(0xFF7F5AF0)],
  [Color(0xFF2EE6A6), Color(0xFF2CB1FF)],
  [Color(0xFFFFC857), Color(0xFFFF6AD5)],
  [Color(0xFF9D7BFF), Color(0xFF2EE6A6)],
];

/// Gradient avatar with initials and an optional presence dot.
class GlossyAvatar extends StatelessWidget {
  final String name;
  final String seed;
  final double size;
  final bool? online;

  const GlossyAvatar({super.key, required this.name, required this.seed, this.size = 52, this.online});

  String get _initials {
    final parts = name.trim().split(RegExp(r'[\s._-]+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[seed.codeUnits.fold<int>(0, (a, b) => a + b) % _palettes.length];
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.45), blurRadius: 14, offset: const Offset(0, 5))],
            ),
            child: Stack(children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Text(
                  _initials,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36),
                ),
              ),
            ]),
          ),
          if (online != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online! ? AppColors.mint : const Color(0xFF5B6085),
                  border: Border.all(color: AppColors.bgMid, width: 2.5),
                  boxShadow: online!
                      ? [BoxShadow(color: AppColors.mint.withValues(alpha: 0.7), blurRadius: 8)]
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
