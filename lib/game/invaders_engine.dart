import 'dart:math' as math;

import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/level_plan.dart';

class InvadersLevel {
  final ArcadeMeta meta;
  final int cols;
  final int rows;
  final int waves; // formation waves before the (optional) boss, 0 = endless
  final bool boss;
  final double speed;
  final int fireEvery;
  final double bulletSpeed;
  final bool armored;
  final bool divers;
  final bool ufo;
  final bool shields;

  const InvadersLevel({
    required this.meta,
    required this.cols,
    required this.rows,
    required this.waves,
    required this.boss,
    required this.speed,
    required this.fireEvery,
    required this.bulletSpeed,
    required this.armored,
    required this.divers,
    required this.ufo,
    required this.shields,
  });

  int get totalWaves => waves + (boss ? 1 : 0);
}

InvadersLevel generateInvadersLevel(LevelSpec spec) {
  final m = ArcadeMeta.of(spec);
  final d = spec.difficulty;
  final boss = m.goal && (spec.has('boss') || spec.levelId % 10 == 0 && spec.levelId > 0);
  return InvadersLevel(
    meta: m,
    cols: (6 + d ~/ 3).clamp(6, 9),
    rows: (3 + d ~/ 3).clamp(3, 6),
    waves: m.goal ? (1 + d ~/ 4).clamp(1, 3) : 0,
    boss: boss,
    speed: 0.8 + d * 0.12,
    fireEvery: (80 - d * 5).clamp(30, 80),
    bulletSpeed: 6.5 + d * 0.35,
    armored: spec.has('armored') || d >= 8,
    divers: spec.has('divers'),
    ufo: spec.has('ufo') || !m.goal,
    shields: !spec.has('no_shields'),
  );
}

const double kPlayerY = 1480;
const double kEnemyW = 70;
const double kEnemyH = 50;
const double kSpaceX = 96;
const double kSpaceY = 76;

class Enemy {
  final int col, row;
  int hp;
  final int type; // row-based look
  bool diving = false;
  double dx = 0, dy = 0; // offset while diving
  Enemy(this.col, this.row, this.hp, this.type);
}

class Shot {
  double x, y, vx, vy;
  Shot(this.x, this.y, this.vx, this.vy);
}

class InvadersSim extends ArcadeSim {
  final InvadersLevel level;
  double px = kWorldW / 2;
  final List<Enemy> enemies = [];
  final List<Shot> shots = [];
  final List<Shot> enemyShots = [];
  final List<Shot> drops = []; // vx = kind
  final List<int> shieldHp = [];
  double fx = 0, fy = 200;
  int fdir = 1;
  int wave = 0;
  int cooldown = 0;
  int rapid = 0, triple = 0;
  int kills = 0, wavesCleared = 0, ufos = 0;
  double ufoX = -1;
  int ufoDir = 1;
  int bossHp = 0, bossMax = 0;
  double bossX = 500;
  int bossDir = 1;
  int totalInWave = 1;
  int lastEvent = 0; // 1 kill, 2 shot, 3 boss hit

  InvadersSim(this.level) : super(level.meta) {
    _nextWave();
    if (level.shields) _resetShields();
  }

  static const shieldCols = 6, shieldRows = 3, shieldBlock = 28.0;
  static const shieldY = 1290.0;

  double shieldX(int s) => 170 + s * 330 - shieldCols * shieldBlock / 2;

  void _resetShields() {
    shieldHp
      ..clear()
      ..addAll(List.filled(3 * shieldCols * shieldRows, 2));
  }

  bool get bossWave => level.boss && wave == level.totalWaves;

  void _nextWave() {
    wave++;
    enemies.clear();
    enemyShots.clear();
    if (bossWave) {
      bossMax = 18 + meta.difficulty * 4;
      bossHp = bossMax;
      bossX = 500;
      totalInWave = 1;
      return;
    }
    final rows = level.rows + (meta.goal ? 0 : ((wave - 1) ~/ 2).clamp(0, 2));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < level.cols; c++) {
        final hp = level.armored && r == 0 ? 2 : 1;
        enemies.add(Enemy(c, r, hp, r % 3));
      }
    }
    totalInWave = enemies.length;
    fx = (kWorldW - (level.cols - 1) * kSpaceX) / 2;
    fy = 200;
    fdir = 1;
  }

  double ex(Enemy e) => fx + e.col * kSpaceX + e.dx;
  double ey(Enemy e) => fy + e.row * kSpaceY + e.dy;

  double get waveSpeed {
    final alive = enemies.length / math.max(1, totalInWave);
    final endlessBoost = meta.goal ? 0 : (wave - 1) * 0.15;
    return (level.speed + endlessBoost) * (1 + (1 - alive) * 1.6);
  }

  @override
  void update(ArcadeInput input) {
    lastEvent = 0;
    if (rapid > 0) rapid--;
    if (triple > 0) triple--;
    if (input.hasPointer && input.down) {
      px = moveToward(px, input.x, 16);
    } else if (input.dirX != 0) {
      px += input.dirX * 14;
    }
    px = clampD(px, 50, kWorldW - 50);
    // Fire: automatic, a tap fires immediately when ready.
    if (cooldown > 0) cooldown--;
    if (cooldown == 0 && (shots.length < 4 || input.tap)) {
      shots.add(Shot(px, kPlayerY - 40, 0, -24));
      if (triple > 0) {
        shots.add(Shot(px, kPlayerY - 40, -4, -23));
        shots.add(Shot(px, kPlayerY - 40, 4, -23));
      }
      cooldown = rapid > 0 ? 9 : 20;
      lastEvent = 2;
    }
    _moveFormation();
    _moveShots();
    _enemyFire();
    _ufo();
    if (bossWave) _boss();
    if ((bossWave ? bossHp <= 0 : enemies.isEmpty) && !over) {
      wavesCleared++;
      score += 100 * wave;
      if (meta.goal && wave >= level.totalWaves) {
        win();
      } else {
        _nextWave();
      }
    }
  }

  void _moveFormation() {
    if (enemies.isEmpty) return;
    fx += fdir * waveSpeed;
    var minX = 1e9, maxX = -1e9, maxY = -1e9;
    for (final e in enemies) {
      if (e.diving) continue;
      minX = math.min(minX, ex(e));
      maxX = math.max(maxX, ex(e));
      maxY = math.max(maxY, ey(e));
    }
    if (minX < 50 && fdir < 0 || maxX > kWorldW - 50 && fdir > 0) {
      fdir = -fdir;
      fy += 30;
    }
    if (maxY + kEnemyH / 2 > shieldY - 10 && level.shields) {
      // Invaders crush the shields.
      for (var i = 0; i < shieldHp.length; i++) {
        shieldHp[i] = 0;
      }
    }
    if (maxY + kEnemyH / 2 >= kPlayerY - 50) {
      hit();
      if (meta.zen) fy -= 300;
    }
    // Divers.
    if (level.divers && ticks % 300 == 150) {
      final cands = enemies.where((e) => !e.diving).toList();
      if (cands.isNotEmpty) cands[rng.nextInt(cands.length)].diving = true;
    }
    for (final e in enemies) {
      if (!e.diving) continue;
      final tx = px - (fx + e.col * kSpaceX);
      e.dx = moveToward(e.dx, tx, 3.5);
      e.dy += 5;
      if (ey(e) > kWorldH + 40) {
        e.diving = false;
        e.dx = 0;
        e.dy = 0;
      }
      if ((ex(e) - px).abs() < 60 && (ey(e) - kPlayerY).abs() < 45) {
        hit();
        e.diving = false;
        e.dx = 0;
        e.dy = 0;
      }
    }
  }

  bool shieldBlocks(double x, double y) => _shieldAt(x, y) >= 0;

  int _shieldAt(double x, double y) {
    if (!level.shields || y < shieldY || y >= shieldY + shieldRows * shieldBlock) return -1;
    for (var s = 0; s < 3; s++) {
      final x0 = shieldX(s);
      if (x < x0 || x >= x0 + shieldCols * shieldBlock) continue;
      final c = ((x - x0) / shieldBlock).floor(), r = ((y - shieldY) / shieldBlock).floor();
      final i = (s * shieldRows + r) * shieldCols + c;
      return shieldHp[i] > 0 ? i : -1;
    }
    return -1;
  }

  void _moveShots() {
    for (final s in [...shots]) {
      s.x += s.vx;
      s.y += s.vy;
      if (s.y < 100) {
        shots.remove(s);
        continue;
      }
      final si = _shieldAt(s.x, s.y);
      if (si >= 0) {
        shieldHp[si]--;
        shots.remove(s);
        continue;
      }
      var hitSomething = false;
      for (final e in enemies) {
        if ((ex(e) - s.x).abs() < kEnemyW / 2 && (ey(e) - s.y).abs() < kEnemyH / 2) {
          e.hp--;
          hitSomething = true;
          if (e.hp <= 0) {
            enemies.remove(e);
            kills++;
            score += 10 * (3 - e.type) + 10;
            lastEvent = 1;
            if (rng.chance(0.05)) drops.add(Shot(ex(e), ey(e), rng.nextInt(2).toDouble(), 5));
          }
          break;
        }
      }
      if (!hitSomething && ufoX >= 0 && (s.x - ufoX).abs() < 60 && (s.y - 150).abs() < 30) {
        ufos++;
        score += 150;
        ufoX = -1;
        hitSomething = true;
      }
      if (!hitSomething && bossWave && bossHp > 0 && (s.x - bossX).abs() < 130 && (s.y - 320).abs() < 60) {
        bossHp--;
        score += 5;
        lastEvent = 3;
        hitSomething = true;
        if (bossHp <= 0) score += 1000;
      }
      if (hitSomething) shots.remove(s);
    }
    for (final s in [...enemyShots]) {
      s.x += s.vx;
      s.y += s.vy;
      final si = _shieldAt(s.x, s.y);
      if (si >= 0) {
        shieldHp[si]--;
        enemyShots.remove(s);
        continue;
      }
      if ((s.x - px).abs() < 42 && (s.y - kPlayerY).abs() < 30) {
        enemyShots.remove(s);
        hit();
        continue;
      }
      if (s.y > kWorldH) enemyShots.remove(s);
    }
    for (final d in [...drops]) {
      d.y += d.vy;
      if ((d.x - px).abs() < 55 && (d.y - kPlayerY).abs() < 35) {
        if (d.vx == 0) {
          rapid = 600;
        } else {
          triple = 600;
        }
        score += 20;
        drops.remove(d);
      } else if (d.y > kWorldH) {
        drops.remove(d);
      }
    }
  }

  void _enemyFire() {
    if (enemies.isEmpty || ticks % level.fireEvery != 0) return;
    // Bottom-most enemy of a random column.
    final cols = enemies.map((e) => e.col).toSet().toList()..sort();
    final c = cols[rng.nextInt(cols.length)];
    Enemy? low;
    for (final e in enemies) {
      if (e.col == c && !e.diving && (low == null || e.row > low.row)) low = e;
    }
    if (low != null) enemyShots.add(Shot(ex(low), ey(low) + 30, 0, level.bulletSpeed));
  }

  void _ufo() {
    if (!level.ufo) return;
    if (ufoX < 0 && ticks % 900 == 450) {
      ufoDir = rng.chance(0.5) ? 1 : -1;
      ufoX = ufoDir > 0 ? 0 : kWorldW;
    }
    if (ufoX >= 0) {
      ufoX += ufoDir * 4;
      if (ufoX < 0 || ufoX > kWorldW) ufoX = -1;
    }
  }

  void _boss() {
    if (bossHp <= 0) return;
    bossX += bossDir * (2.5 + meta.difficulty * 0.2);
    if (bossX < 150 || bossX > kWorldW - 150) bossDir = -bossDir;
    if (ticks % (level.fireEvery ~/ 2 + 10) == 0) {
      for (final vx in const [-2.5, 0.0, 2.5]) {
        enemyShots.add(Shot(bossX, 380, vx, level.bulletSpeed));
      }
    }
  }

  @override
  void onLifeLost() {
    enemyShots.clear();
    fy = math.max(160, fy - 160);
    for (final e in enemies) {
      e.diving = false;
      e.dx = 0;
      e.dy = 0;
    }
  }

  @override
  bool useBooster() {
    // Triple shot + rapid fire.
    if (over) return false;
    triple = 600;
    rapid = 600;
    return true;
  }

  @override
  double get progress {
    if (level.totalWaves == 0) return 0;
    final inWave = bossWave
        ? 1 - bossHp / math.max(1, bossMax)
        : 1 - enemies.length / math.max(1, totalInWave);
    return ((wave - 1) + inWave) / level.totalWaves;
  }

  @override
  String get goalText => meta.goal ? '$wave/${level.totalWaves}' : 'W$wave';

  @override
  Map<String, int> get stats => {'aliens_destroyed': kills, 'waves_cleared': wavesCleared, 'ufos': ufos};

  @override
  int get stars => lifeStars(this, 3);
}

/// Autopilot: dodge incoming shots and divers, otherwise line up under the
/// lowest alien (or the boss / UFO).
ArcadeInput invadersBot(ArcadeSim sim) {
  final g = sim as InvadersSim;
  double target;
  if (g.bossWave && g.bossHp > 0) {
    target = g.bossX;
  } else if (g.enemies.isNotEmpty) {
    Enemy? best;
    var bd = 1e9;
    for (final e in g.enemies) {
      final d = (g.ex(e) - g.px).abs() - g.ey(e) * 0.6;
      if (d < bd) {
        bd = d;
        best = e;
      }
    }
    // Lead the moving formation a little.
    target = g.ex(best!) + g.fdir * g.waveSpeed * 20;
  } else {
    target = g.px;
  }
  /// Exact prediction of known shots while moving toward [x].
  bool safe(double x) {
    for (final s in g.enemyShots) {
      final k0 = ((kPlayerY - 40 - s.y) / s.vy).ceil().clamp(1, 76);
      final k1 = ((kPlayerY + 40 - s.y) / s.vy).floor().clamp(0, 75);
      for (var k = k0; k <= k1; k++) {
        final pk = moveToward(g.px, x, 16.0 * k);
        if ((s.x + s.vx * k - pk).abs() < 58) return false;
      }
    }
    for (final e in g.enemies) {
      if (e.diving && (g.ex(e) - x).abs() < 120 && g.ey(e) > kPlayerY - 600) return false;
    }
    return true;
  }

  var best = g.px;
  var bestCost = 1e18;
  for (var x = 50.0; x <= kWorldW - 50; x += 20) {
    if (!safe(x)) continue;
    var cost = (x - target).abs() + (x - g.px).abs() * 0.3;
    // Own shots would be blocked by an intact shield above.
    for (var y = InvadersSim.shieldY; y < InvadersSim.shieldY + 80; y += 28) {
      if (g.shieldBlocks(x, y)) {
        cost += 400;
        break;
      }
    }
    // Stay out from under the firing columns.
    for (final e in g.enemies) {
      if ((g.ex(e) - x).abs() < 40) cost += 6;
    }
    if (cost < bestCost) {
      bestCost = cost;
      best = x;
    }
  }
  if (bestCost == 1e18) {
    // Nothing safe: move away from the nearest shot.
    Shot? near;
    var nd = 1e9;
    for (final s in g.enemyShots) {
      final d = (kPlayerY - s.y).abs();
      if (d < nd) {
        nd = d;
        near = s;
      }
    }
    best = near == null ? g.px : (near.x > g.px ? g.px - 120 : g.px + 120);
  }
  return ArcadeInput(down: true, x: clampD(best, 0, kWorldW), y: kPlayerY);
}
