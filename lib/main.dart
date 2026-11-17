import 'dart:async';
import 'package:flutter/material.dart';
import 'game/invader_engine.dart';

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: InvaderScreen(),
));

class InvaderScreen extends StatefulWidget {
  const InvaderScreen({super.key});

  @override
  State<InvaderScreen> createState() => _InvaderScreenState();
}

class _InvaderScreenState extends State<InvaderScreen> {
  final InvaderEngine engine = InvaderEngine();
  Timer? timer;

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted) return;
      setState(() => engine.tick(0.016));
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080E25),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111B39),
        foregroundColor: Colors.white,
        title: Text('Space Invaders Neo • ${engine.score}'),
        actions: [
          IconButton(
            tooltip: engine.paused ? 'Devam et' : 'Duraklat',
            icon: Icon(engine.paused ? Icons.play_arrow : Icons.pause),
            onPressed: () => setState(() => engine.paused = !engine.paused),
          ),
          IconButton(
            tooltip: 'Yeniden başlat',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(engine.reset),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Dalga ${engine.wave}   •   Can ${engine.lives}   •   '
                '${engine.gameOver ? "Oyun bitti" : engine.paused ? "Duraklatıldı" : "Hazır"}',
                style: const TextStyle(color: Colors.white, fontSize: 17),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragUpdate: (details) {
                    setState(() => engine.movePlayer(
                      details.localPosition.dx / constraints.maxWidth * engine.width,
                    ));
                  },
                  onTapDown: (details) {
                    setState(() {
                      engine.movePlayer(
                        details.localPosition.dx / constraints.maxWidth * engine.width,
                      );
                      engine.fire();
                    });
                  },
                  child: CustomPaint(
                    painter: _InvaderPainter(engine),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => setState(() {
                  if (engine.gameOver) engine.reset();
                  engine.fire();
                }),
                icon: const Icon(Icons.flash_on),
                label: Text(engine.gameOver ? 'Tekrar oyna' : 'ATEŞ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvaderPainter extends CustomPainter {
  const _InvaderPainter(this.engine);
  final InvaderEngine engine;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / engine.width;
    final sy = size.height / engine.height;
    canvas.save();
    canvas.scale(sx, sy);
    final enemyPaint = Paint()..color = const Color(0xFF7BE7C4);
    final playerPaint = Paint()..color = const Color(0xFF6FA8FF);
    final shotPaint = Paint()..color = Colors.amber;
    for (final enemy in engine.invaders) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(enemy.x, enemy.y), width: 30, height: 22),
          const Radius.circular(5),
        ),
        enemyPaint,
      );
    }
    for (final shot in engine.shots) {
      canvas.drawRect(Rect.fromCenter(
        center: Offset(shot.x, shot.y), width: 4, height: 14,
      ), shotPaint);
    }
    final path = Path()
      ..moveTo(engine.playerX, engine.height - 80)
      ..lineTo(engine.playerX - 20, engine.height - 40)
      ..lineTo(engine.playerX + 20, engine.height - 40)
      ..close();
    canvas.drawPath(path, playerPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InvaderPainter oldDelegate) => true;
}
