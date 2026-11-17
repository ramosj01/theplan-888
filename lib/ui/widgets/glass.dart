import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Deep gradient backdrop with slowly drifting, blurred colour orbs.
class GlossyBackground extends StatefulWidget {
  final Widget child;
  const GlossyBackground({super.key, required this.child});

  @override
  State<GlossyBackground> createState() => _GlossyBackgroundState();
}

class _GlossyBackgroundState extends State<GlossyBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.55), color.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.background),
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = _c.value * 2 * math.pi;
              final size = MediaQuery.sizeOf(context);
              return Stack(children: [
                Positioned(
                  left: -120 + 40 * math.sin(t),
                  top: -80 + 30 * math.cos(t),
                  child: _orb(AppColors.violet, 420),
                ),
                Positioned(
                  right: -140 + 50 * math.cos(t),
                  top: size.height * 0.35 + 40 * math.sin(t),
                  child: _orb(AppColors.cyan, 380),
                ),
                Positioned(
                  left: size.width * 0.1 + 30 * math.cos(t * 2),
                  bottom: -160 + 40 * math.sin(t),
                  child: _orb(AppColors.pink, 360),
                ),
              ]);
            },
          ),
          Positioned.fill(child: widget.child),
        ],
      ),
    );
  }
}

/// Frosted-glass panel with a subtle top highlight.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.blur = 18,
    this.opacity = 0.08,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: br,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: br,
            splashColor: Colors.white10,
            highlightColor: Colors.white.withValues(alpha: 0.04),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: br,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: opacity + 0.06),
                    Colors.white.withValues(alpha: opacity * 0.4),
                  ],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill button with gradient fill, glassy sheen and soft glow.
class GlossyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final Gradient gradient;
  final double height;

  const GlossyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.gradient = AppColors.accent,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.violet.withValues(alpha: enabled ? 0.45 : 0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: enabled ? onPressed : null,
            child: Stack(
              children: [
                // Glossy sheen across the top half.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: height / 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(height / 2)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.02)],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (icon != null) ...[
                              Icon(icon, color: Colors.white, size: 20),
                              const SizedBox(width: 10),
                            ],
                            Text(
                              label,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Round frosted icon button.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final Color? color;

  const GlassIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.size = 44, this.color});

  @override
  Widget build(BuildContext context) {
    final btn = SizedBox(
      width: size,
      height: size,
      child: GlassCard(
        padding: EdgeInsets.zero,
        radius: size / 2,
        onTap: onPressed,
        child: Center(child: Icon(icon, size: size * 0.48, color: color ?? AppColors.textPrimary)),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

/// Text field styled as a glass capsule.
class GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final int? maxLines;
  final List<String>? autofillHints;

  const GlassTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.keyboardType,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    this.maxLines = 1,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      radius: 20,
      child: Row(
        children: [
          if (icon != null) ...[
            ShaderMask(
              shaderCallback: (r) => AppColors.accent.createShader(r),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              maxLines: maxLines,
              minLines: 1,
              autofillHints: autofillHints,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
              cursorColor: AppColors.cyan,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient text for headlines.
class GradientText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  const GradientText(this.text, {super.key, this.style, this.gradient = AppColors.accent});

  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => gradient.createShader(Rect.fromLTWH(0, 0, r.width, r.height)),
        child: Text(text, style: style),
      );
}

/// Glossy app mark: a chat bubble with a lock.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          colors: [AppColors.pink, AppColors.violet, AppColors.cyan],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: AppColors.violet.withValues(alpha: 0.6), blurRadius: size * 0.4, offset: Offset(0, size * 0.12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size * 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.vertical(top: Radius.circular(size * 0.3)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Center(child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: size * 0.56)),
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.06),
              child: Icon(Icons.lock_rounded, color: AppColors.violet, size: size * 0.26),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small rounded status pill.
class StatusPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool pulsing;
  const StatusPill({super.key, required this.label, required this.icon, required this.color, this.pulsing = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulsing
              ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: color))
              : Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
