import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'logic/game_notifier.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/end_screen.dart';
import 'services/audio_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — the board layout is tuned for vertical screens.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Use a translucent status bar that complements the dark theme.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0a0f1e),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize audio service for proper mobile audio support
  await AudioService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => GameNotifier(),
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
      // Global route generation that uses our custom fade-through transition
      // for every page pushed by the app.
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
            if (currentChild != null) currentChild,
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
