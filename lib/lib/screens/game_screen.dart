import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../logic/game_notifier.dart';
import '../../widgets/board_widget.dart';
import '../widgets/hud_widget.dart';
import '../theme/space_theme.dart';

const _yardAlignments = [
  Alignment.bottomLeft,
  Alignment.topLeft,
  Alignment.topRight,
  Alignment.bottomRight,
];

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF090E24), Color(0xFF1E103C)],
          )
        ),
        child: Stack(
          children: [
            SpaceTheme.backgroundStars(),
            Positioned.fill(
              child: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/images/bg.png', fit: BoxFit.cover, errorBuilder: (_,__,___) => const SizedBox()),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight;
                        return SizedBox(
                          width: size,
                          height: size,
                          child: const BoardWidget(),
                        );
                      },
                    ),
                  ),
                  _HudOverlay(),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _buildGlossyIconBtn(
                      icon: Icons.close,
                      onTap: () => _confirmLeave(context, game),
                      isPurple: false,
                    ),
                  ),
                  if (game.toast != null)
                    Positioned(
                      top: 60,
                      left: 0,
                      right: 0,
                      child: Center(child: _ToastWidget(message: game.toast!)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlossyIconBtn({required IconData icon, required VoidCallback onTap, required bool isPurple}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 44, height: 44,
            decoration: SpaceTheme.buttonDecoration(isPurple: isPurple).copyWith(
              borderRadius: BorderRadius.circular(12)
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          SpaceTheme.glossyOverlay(44, 44, 12),
        ],
      ),
    );
  }

  void _confirmLeave(BuildContext context, GameNotifier game) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: SpaceTheme.panelDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('EXIT MATCH?', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              const SizedBox(height: 12),
              const Text('Current progress will be lost.', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildGlossyTextBtn(label: 'NO', isPurple: false, onTap: () => Navigator.pop(context)),
                   _buildGlossyTextBtn(label: 'YES', isPurple: true, onTap: () { Navigator.pop(context); game.leaveMatch(); }),
                ]
              )
            ]
          )
        )
      )
    );
  }

  Widget _buildGlossyTextBtn({required String label, required VoidCallback onTap, required bool isPurple}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 100,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: SpaceTheme.buttonDecoration(isPurple: isPurple),
            child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1))),
          ),
          SpaceTheme.glossyOverlay(100, 44, 16),
        ],
      ),
    );
  }
}

class _HudOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameNotifier>();
    final actId = game.activePlayerId;
    final alignment = _yardAlignments[actId];

    return AnimatedAlign(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: alignment,
      child: Padding(padding: _pad(alignment), child: const HudWidget()),
    );
  }

  EdgeInsets _pad(Alignment a) {
    const p = 12.0;
    if (a == Alignment.topLeft) return const EdgeInsets.only(top: p, left: p);
    if (a == Alignment.topRight) return const EdgeInsets.only(top: p, right: p);
    if (a == Alignment.bottomLeft)
      return const EdgeInsets.only(bottom: p, left: p);
    return const EdgeInsets.only(bottom: p, right: p);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  const _ToastWidget({required this.message});
  @override State<_ToastWidget> createState() => _ToastWidgetState();
}
class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl; late Animation<double> _anim;
  @override void initState() { super.initState(); _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true); _anim = Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)); }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) => Transform.translate(offset: Offset(0, _anim.value), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: SpaceTheme.panelDecoration.copyWith(
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(widget.message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1)),
      ),
    );
  }
}
