import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Gradient backdrop with slowly drifting, blurred brand-colour orbs. Also
/// sets the status bar icon brightness for the active mode.
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

  Widget _orb(Color color, double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: opacity), color.withValues(alpha: 0)]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (p.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: p.background,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(gradient: p.backgroundGradient),
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final t = _c.value * 2 * math.pi;
                final size = MediaQuery.sizeOf(context);
                final o = p.orbOpacity;
                return Stack(children: [
                  Positioned(
                    left: -120 + 40 * math.sin(t),
                    top: -80 + 30 * math.cos(t),
                    child: _orb(AppColors.indigo, 420, o),
                  ),
                  Positioned(
                    right: -140 + 50 * math.cos(t),
                    top: size.height * 0.35 + 40 * math.sin(t),
                    child: _orb(AppColors.sky, 380, o * 0.9),
                  ),
                  Positioned(
                    left: size.width * 0.1 + 30 * math.cos(t * 2),
                    bottom: -160 + 40 * math.sin(t),
                    child: _orb(AppColors.violet, 360, o),
                  ),
                ]);
              },
            ),
            Positioned.fill(child: widget.child),
          ],
        ),
      ),
    );
  }
}

/// Frosted-glass panel.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  /// Optional solid fill (e.g. chat bubble colour) instead of the glass tint.
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 24,
    this.blur = 18,
    this.onTap,
    this.borderRadius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final br = borderRadius ?? BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [BoxShadow(color: p.glassShadow, blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: br,
              splashColor: AppColors.indigo.withValues(alpha: 0.08),
              highlightColor: AppColors.indigo.withValues(alpha: 0.04),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  borderRadius: br,
                  color: color,
                  gradient: color != null
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [p.glassTop, p.glassBottom],
                        ),
                  border: Border.all(color: p.glassBorder, width: 1),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill button with gradient fill, glossy sheen and soft glow.
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
    final glow = gradient.colors.first;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: gradient,
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: enabled ? 0.38 : 0.12),
              blurRadius: 22,
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
                        colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0.0)],
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

/// Outlined pill button (the "Call" style from the NEXA kit).
class OutlineGlossyButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double height;

  const OutlineGlossyButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.color,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.bubbleSent;
    return SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          backgroundColor: c.withValues(alpha: 0.06),
          side: BorderSide(color: c, width: 1.5),
          shape: const StadiumBorder(),
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
        child: Center(child: Icon(icon, size: size * 0.48, color: color ?? context.palette.textPrimary)),
      ),
    );
    return Semantics(
      button: true,
      label: tooltip,
      child: tooltip == null ? btn : Tooltip(message: tooltip!, child: btn),
    );
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
    final p = context.palette;
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
              style: TextStyle(color: p.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: p.textSecondary.withValues(alpha: 0.8)),
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

/// Glossy app mark: a chat bubble with a lock, in the NEXA logo gradient.
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
        gradient: AppColors.logo,
        boxShadow: [
          BoxShadow(
              color: AppColors.indigo.withValues(alpha: 0.45), blurRadius: size * 0.4, offset: Offset(0, size * 0.12)),
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
                  colors: [Colors.white.withValues(alpha: 0.4), Colors.white.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ),
          Center(child: Icon(Icons.chat_bubble_rounded, color: Colors.white, size: size * 0.56)),
          Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: size * 0.06),
              child: Icon(Icons.lock_rounded, color: AppColors.indigo, size: size * 0.26),
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
    // Darken the text slightly in light mode for contrast on pale fills.
    final fg = context.palette.isDark ? color : Color.lerp(color, Colors.black, 0.22)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pulsing
              ? SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 1.6, color: fg))
              : Icon(icon, size: 12, color: fg),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Light / dark toggle as a frosted icon button.
class ThemeToggleButton extends StatelessWidget {
  final ThemeController controller;
  const ThemeToggleButton({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final dark = context.palette.isDark;
    return GlassIconButton(
      icon: dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
      tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
      color: dark ? AppColors.warning : AppColors.indigo,
      onPressed: () => controller.toggle(Theme.of(context).brightness),
    );
  }
}
