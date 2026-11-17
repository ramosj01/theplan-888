import 'package:cipherly/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light palette matches NEXA spec', () {
    const p = AppPalette.light;
    expect(p.background, const Color(0xFFFFFFFF));
    expect(p.surface, const Color(0xFFF5F7FB));
    expect(p.bubbleReceived, const Color(0xFFE8EDFF));
    expect(p.bubbleSent, const Color(0xFF5865F2));
    expect(p.textPrimary, const Color(0xFF1F2937));
    expect(p.textSecondary, const Color(0xFF6B7280));
    expect(p.divider, const Color(0xFFE5E7EB));
  });

  test('dark palette matches NEXA spec', () {
    const p = AppPalette.dark;
    expect(p.background, const Color(0xFF101321));
    expect(p.surface, const Color(0xFF1C2030));
    expect(p.bubbleReceived, const Color(0xFF343C70));
    expect(p.bubbleSent, const Color(0xFF6366F1));
    expect(p.textPrimary, const Color(0xFFF8FAFC));
    expect(p.textSecondary, const Color(0xFF94A3B8));
    expect(p.divider, const Color(0xFF2A2F45));
  });

  test('themes expose the palette extension and brightness', () {
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.extension<AppPalette>(), AppPalette.light);
    expect(AppTheme.dark.extension<AppPalette>(), AppPalette.dark);
    expect(AppTheme.light.colorScheme.primary, AppColors.indigo);
  });

  test('theme controller toggles and persists', () async {
    ThemeMode? saved;
    final c = ThemeController(ThemeMode.system, (m) async => saved = m);
    c.toggle(Brightness.light);
    expect(c.mode, ThemeMode.dark);
    expect(saved, ThemeMode.dark);
    c.toggle(Brightness.dark);
    expect(c.mode, ThemeMode.light);
  });
}
