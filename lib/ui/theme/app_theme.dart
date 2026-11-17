import 'package:flutter/material.dart';

/// NEXA palette: brand and status colours shared by light and dark mode.
class AppColors {
  // Brand
  static const indigo = Color(0xFF5865F2);
  static const violet = Color(0xFF8B5CF6);
  static const sky = Color(0xFF0EA5E9);
  static const teal = Color(0xFF14B8A6);

  // Accent & status
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF0EA5E9);
  static const purple = Color(0xFFA855F7);

  /// Primary call-to-action gradient (Send Message button).
  static const accent = LinearGradient(
    colors: [indigo, violet],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Cool secondary gradient for badges and icons.
  static const cool = LinearGradient(
    colors: [sky, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Warm secondary gradient.
  static const warm = LinearGradient(
    colors: [violet, purple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Logo gradient (sky -> indigo -> violet).
  static const logo = LinearGradient(
    colors: [sky, indigo, violet],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const danger = LinearGradient(colors: [error, Color(0xFFF43F5E)]);
}

/// Mode-specific colours, exposed as a [ThemeExtension] so widgets resolve
/// them from the active theme via `context.palette`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color bubbleReceived;
  final Color bubbleSent;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;

  /// Gradient end colour of the page background.
  final Color backgroundEnd;

  /// Frosted glass fill (top -> bottom) and outline.
  final Color glassTop;
  final Color glassBottom;
  final Color glassBorder;
  final Color glassShadow;

  /// Strength of the drifting colour orbs behind content.
  final double orbOpacity;

  const AppPalette({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.bubbleReceived,
    required this.bubbleSent,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.backgroundEnd,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBorder,
    required this.glassShadow,
    required this.orbOpacity,
  });

  static const light = AppPalette(
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFF5F7FB),
    bubbleReceived: Color(0xFFE8EDFF),
    bubbleSent: Color(0xFF5865F2),
    textPrimary: Color(0xFF1F2937),
    textSecondary: Color(0xFF6B7280),
    divider: Color(0xFFE5E7EB),
    backgroundEnd: Color(0xFFEEF1FF),
    glassTop: Color(0xD9FFFFFF),
    glassBottom: Color(0x99F5F7FB),
    glassBorder: Color(0xFFE5E7EB),
    glassShadow: Color(0x145865F2),
    orbOpacity: 0.20,
  );

  static const dark = AppPalette(
    brightness: Brightness.dark,
    background: Color(0xFF101321),
    surface: Color(0xFF1C2030),
    bubbleReceived: Color(0xFF343C70),
    bubbleSent: Color(0xFF6366F1),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    divider: Color(0xFF2A2F45),
    backgroundEnd: Color(0xFF1C2030),
    glassTop: Color(0x1AFFFFFF),
    glassBottom: Color(0x08FFFFFF),
    glassBorder: Color(0xFF2A2F45),
    glassShadow: Color(0x00000000),
    orbOpacity: 0.30,
  );

  bool get isDark => brightness == Brightness.dark;

  LinearGradient get backgroundGradient => LinearGradient(
        colors: [background, surface, backgroundEnd],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Sent-bubble gradient starting from the mode's sent colour.
  LinearGradient get sentBubbleGradient => LinearGradient(
        colors: [bubbleSent, AppColors.violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  AppPalette copyWith() => this;

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      brightness: t < 0.5 ? brightness : other.brightness,
      background: c(background, other.background),
      surface: c(surface, other.surface),
      bubbleReceived: c(bubbleReceived, other.bubbleReceived),
      bubbleSent: c(bubbleSent, other.bubbleSent),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      divider: c(divider, other.divider),
      backgroundEnd: c(backgroundEnd, other.backgroundEnd),
      glassTop: c(glassTop, other.glassTop),
      glassBottom: c(glassBottom, other.glassBottom),
      glassBorder: c(glassBorder, other.glassBorder),
      glassShadow: c(glassShadow, other.glassShadow),
      orbOpacity: orbOpacity + (other.orbOpacity - orbOpacity) * t,
    );
  }
}

extension PaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

class AppTheme {
  static ThemeData get light => _build(AppPalette.light);
  static ThemeData get dark => _build(AppPalette.dark);

  static ThemeData _build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.indigo,
      brightness: p.brightness,
    ).copyWith(
      primary: p.bubbleSent,
      onPrimary: Colors.white,
      secondary: AppColors.violet,
      tertiary: AppColors.sky,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.divider,
      outlineVariant: p.divider,
      error: AppColors.error,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: p.brightness);
    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      extensions: [p],
      dividerColor: p.divider,
      textTheme: base.textTheme.apply(bodyColor: p.textPrimary, displayColor: p.textPrimary).copyWith(
            headlineLarge: TextStyle(
                fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, color: p.textPrimary),
            headlineMedium: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: p.textPrimary),
            titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary),
            bodyMedium: TextStyle(fontSize: 15, height: 1.4, color: p.textSecondary),
          ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.isDark ? p.bubbleReceived : p.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.isDark ? p.surface : p.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.bubbleSent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.bubbleSent,
        selectionColor: AppColors.indigo.withValues(alpha: 0.3),
        selectionHandleColor: p.bubbleSent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: Colors.transparent),
    );
  }
}

/// Persisted light / dark / system preference.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode;
  final Future<void> Function(ThemeMode) _persist;

  ThemeController(this._mode, this._persist);

  ThemeMode get mode => _mode;

  set mode(ThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    notifyListeners();
    _persist(m);
  }

  /// Flips between light and dark based on what is currently shown.
  void toggle(Brightness current) =>
      mode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark;
}
