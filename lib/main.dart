import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.bgTop,
  ));
  final backend = await Backend.create();
  runApp(CipherlyApp(backend: backend));
}

class CipherlyApp extends StatelessWidget {
  final Backend backend;
  const CipherlyApp({super.key, required this.backend});

  @override
  Widget build(BuildContext context) {
    return Provider<Backend>.value(
      value: backend,
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        home: const AuthGate(),
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
                  child: Center(child: CircularProgressIndicator(color: AppColors.cyan)),
                ),
              ),
      ),
    );
  }
}
