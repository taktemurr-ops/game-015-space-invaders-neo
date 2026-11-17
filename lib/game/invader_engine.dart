import 'dart:math';

/// Pure, deterministic rules for Space Invaders Neo.
class InvaderEngine {
  InvaderEngine({this.columns = 7, this.rows = 3, this.width = 360, this.height = 600})
      : assert(columns > 0 && rows > 0) {
    reset();
  }

  final int columns;
  final int rows;
  final double width;
  final double height;
  final List<Point<double>> invaders = [];
  final List<Point<double>> shots = [];
  double playerX = 180;
  double direction = 1;
  double enemySpeed = 24;
  int score = 0;
  int lives = 3;
  int wave = 1;
  bool gameOver = false;
  bool paused = false;
  bool won = false;

  void reset() {
    score = 0;
    lives = 3;
    wave = 1;
    playerX = width / 2;
    enemySpeed = 24;
    direction = 1;
    gameOver = false;
    won = false;
    paused = false;
    shots.clear();
    _spawnWave();
  }

  void _spawnWave() {
    invaders.clear();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        invaders.add(Point(35.0 + col * 43, 75.0 + row * 35));
      }
    }
  }

  void movePlayer(double x) {
    if (gameOver || paused) return;
    playerX = x.clamp(18.0, width - 18.0).toDouble();
  }

  void fire() {
    if (gameOver || paused || shots.length >= 2) return;
    shots.add(Point(playerX, height - 62));
  }

  void tick(double dt) {
    if (gameOver || paused || dt <= 0) return;
    // Bound the simulation step after app suspension.
    final step = min(dt, 0.05);
    for (var i = shots.length - 1; i >= 0; i--) {
      final shot = shots[i];
      final next = Point(shot.x, shot.y - 440 * step);
      if (next.y < 0) {
        shots.removeAt(i);
        continue;
      }
      shots[i] = next;
      final hit = invaders.indexWhere(
        (enemy) => (enemy.x - next.x).abs() < 18 && (enemy.y - next.y).abs() < 16,
      );
      if (hit >= 0) {
        invaders.removeAt(hit);
        shots.removeAt(i);
        score += 10;
      }
    }

    if (invaders.isEmpty) {
      wave++;
      enemySpeed = min(100, enemySpeed + 8);
      shots.clear();
      _spawnWave();
      return;
    }

    final nextEdge = invaders.any((enemy) =>
        enemy.x + direction * enemySpeed * step < 18 ||
        enemy.x + direction * enemySpeed * step > width - 18);
    if (nextEdge) {
      direction = -direction;
      for (var i = 0; i < invaders.length; i++) {
        final e = invaders[i];
        invaders[i] = Point(e.x, e.y + 16);
      }
    } else {
      for (var i = 0; i < invaders.length; i++) {
        final e = invaders[i];
        invaders[i] = Point(e.x + direction * enemySpeed * step, e.y);
      }
    }
    if (invaders.any((enemy) => enemy.y >= height - 90)) {
      lives = 0;
      gameOver = true;
    }
  }
}
