import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/game_notifier.dart';
import '../widgets/board_widget.dart';
import '../widgets/hud_widget.dart';

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
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg.png'),
              fit: BoxFit.cover,
            ),
          ),
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
                top: 8,
                right: 8,
                child: _IconBtn(
                  icon: Icons.exit_to_app_rounded,
                  tooltip: 'Leave Match',
                  color: const Color(0xFFef4444),
                  onTap: () => _confirmLeave(context, game),
                ),
              ),
              if (game.toast != null)
                Positioned(
                  top: 52,
                  left: 0,
                  right: 0,
                  child: Center(child: _ToastWidget(message: game.toast!)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, GameNotifier game) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111827),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Leave Match?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Current match progress will be lost.',
          style: TextStyle(color: Color(0xFF94a3b8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF64748b)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              game.leaveMatch();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFef4444),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = const Color(0xFF94a3b8),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xCC111827),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1f2937)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
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
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0,
      end: -8,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) =>
          Transform.translate(offset: Offset(0, _anim.value), child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFF0f172a), width: 3),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 16)],
        ),
        child: Text(
          widget.message,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
