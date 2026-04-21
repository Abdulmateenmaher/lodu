import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'logic/game_notifier.dart';
import 'screens/setup_screen.dart';
import 'screens/game_screen.dart';
import 'screens/end_screen.dart';

void main() {
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
      title: 'Ludo Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(fontFamily: 'sans-serif'),
      home: const _RootRouter(),
    );
  }
}

class _RootRouter extends StatelessWidget {
  const _RootRouter();

  @override
  Widget build(BuildContext context) {
    final phase = context.select<GameNotifier, GamePhase>((g) => g.phase);
    return switch (phase) {
      GamePhase.setup => const SetupScreen(),
      GamePhase.play  => const GameScreen(),
      GamePhase.end   => const EndScreen(),
    };
  }
}
