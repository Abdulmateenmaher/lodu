import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/game_notifier.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/end_screen.dart';
import 'services/audio_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      theme: ThemeData(fontFamily: 'times'),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();

    switch (game.phase) {
      case GamePhase.setup:
        return const SetupScreen();
      case GamePhase.play:
        return const GameScreen();
      case GamePhase.end:
        return const EndScreen();
    }
  }
}
