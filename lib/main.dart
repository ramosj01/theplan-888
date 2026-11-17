import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config.dart';
import 'models/models.dart';
import 'services/backend.dart';
import 'state/chat_controller.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/profile_setup_screen.dart';
import 'ui/screens/welcome_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/glass.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  final backend = await Backend.create();
  final theme = await _loadThemeController();
  runApp(CipherlyApp(backend: backend, theme: theme));
}

const _themeKey = 'ui.theme_mode';

Future<ThemeController> _loadThemeController() async {
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}
  final saved = prefs?.getString(_themeKey);
  final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull ?? ThemeMode.system;
  return ThemeController(mode, (m) async => prefs?.setString(_themeKey, m.name));
}

class CipherlyApp extends StatelessWidget {
  final Backend backend;
  final ThemeController theme;
  const CipherlyApp({super.key, required this.backend, required this.theme});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Backend>.value(value: backend),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
      ],
      child: Consumer<ThemeController>(
        builder: (context, t, _) => MaterialApp(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: t.mode,
          themeAnimationDuration: const Duration(milliseconds: 350),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

/// Routes between onboarding, profile setup and the signed-in experience.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<Backend>().auth;
    return StreamBuilder<AppUser?>(
      stream: auth.userChanges,
      initialData: auth.currentUser,
      builder: (context, snap) {
        final user = snap.data;
        final Widget child;
        if (user == null) {
          child = const WelcomeScreen();
        } else if (user.displayName == null || user.displayName!.trim().isEmpty) {
          child = ProfileSetupScreen(user: user);
        } else {
          child = SessionScope(key: ValueKey(user.id), user: user);
        }
        return AnimatedSwitcher(duration: const Duration(milliseconds: 450), child: child);
      },
    );
  }
}

/// Owns the [ChatController] for the signed-in user.
class SessionScope extends StatefulWidget {
  final AppUser user;
  const SessionScope({super.key, required this.user});

  @override
  State<SessionScope> createState() => _SessionScopeState();
}

class _SessionScopeState extends State<SessionScope> {
  late final ChatController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ChatController(context.read<Backend>(), widget.user)..start();
  }

  @override
  void dispose() {
    _controller.shutdown();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ChatController>(
        builder: (context, c, _) => c.ready
            ? const HomeScreen()
            : const Scaffold(
                body: GlossyBackground(
                  child: Center(child: CircularProgressIndicator(color: AppColors.indigo)),
                ),
              ),
      ),
    );
  }
}
