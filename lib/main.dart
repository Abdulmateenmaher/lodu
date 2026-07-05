import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'logic/game_notifier.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/end_screen.dart';
import 'screens/auth_screens.dart';
import 'services/audio_service.dart';
import 'services/auth_service.dart';
import 'services/firebase_history_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0f1e),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  await AudioService.initialize();

  final authService = AuthService();
  await authService.initialize();

  FirebaseHistoryService();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameNotifier>(create: (_) => GameNotifier()),
        ChangeNotifierProvider<AuthService>.value(value: authService),
      ],
      child: const LudoApp(),
    ),
  );
}

class LudoApp extends StatelessWidget {
  const LudoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'وطني چکه',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      onGenerateRoute: (settings) {
        Widget page;
        switch (settings.name) {
          case '/setup':
            page = const SetupScreen();
            break;
          case '/play':
            page = const GameScreen();
            break;
          case '/end':
            page = const EndScreen();
            break;
          case '/login':
            page = const LoginScreen();
            break;
          case '/signup':
            page = const SignUpScreen();
            break;
          case '/forgot-password':
            page = const ForgotPasswordScreen();
            break;
          default:
            page = const SetupScreen();
        }
        return _FadeThroughRoute(builder: (_) => page);
      },
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();

    return AnimatedSwitcher(
      duration: AppTheme.durSlow,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild, // ignore: use_null_aware_elements
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(game.phase),
        child: _phaseScreen(game.phase),
      ),
    );
  }

  Widget _phaseScreen(GamePhase phase) {
    switch (phase) {
      case GamePhase.setup:
        return const SetupScreen();
      case GamePhase.play:
        return const GameScreen();
      case GamePhase.end:
        return const EndScreen();
    }
  }
}

class _FadeThroughRoute<T> extends PageRouteBuilder<T> {
  _FadeThroughRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: AppTheme.durMed,
          reverseTransitionDuration: AppTheme.durFast,
          pageBuilder: (context, anim, secondary) => builder(context),
          transitionsBuilder: (context, anim, secondary, child) {
            final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: t,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(t),
                child: child,
              ),
            );
          },
        );
}
