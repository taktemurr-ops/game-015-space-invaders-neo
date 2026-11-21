import 'package:flutter/material.dart';

import 'package:studio_core/app/arcade_stage.dart';
import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/arcade.dart';
import 'package:studio_core/core/game_rules.dart';
import 'invaders_engine.dart';
import 'rules.dart';

void _alien(Canvas c, Offset o, int type, Color col, double t) {
  final body = Rect.fromCenter(center: o, width: kEnemyW, height: kEnemyH * 0.7);
  c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(14)), Paint()..color = col);
  final leg = (t * 4).floor().isEven ? 6.0 : -6.0;
  final lp = Paint()
    ..color = col
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  c.drawLine(o.translate(-20, 16), o.translate(-26 + leg, 28), lp);
  c.drawLine(o.translate(20, 16), o.translate(26 - leg, 28), lp);
  if (type == 0) {
    c.drawLine(o.translate(-14, -16), o.translate(-20, -30), lp);
    c.drawLine(o.translate(14, -16), o.translate(20, -30), lp);
  }
  c.drawCircle(o.translate(-12, -2), 7, Paint()..color = Colors.black);
  c.drawCircle(o.translate(12, -2), 7, Paint()..color = Colors.black);
}

void paintInvaders(Canvas c, ArcadeSim sim, ArcadePalette p, double t) {
  final s = sim as InvadersSim;
  // stars
  final star = Paint()..color = Colors.white24;
  for (var i = 0; i < 40; i++) {
    final y = (i * 97 + t * 30 * (1 + i % 3)) % kWorldH;
    c.drawCircle(Offset((i * 211) % kWorldW, y), 2.5, star);
  }
  for (final e in s.enemies) {
    _alien(c, Offset(s.ex(e), s.ey(e)), e.type, e.hp > 1 ? const Color(0xFFADB5BD) : p.piece(e.type), t);
  }
  if (s.bossWave && s.bossHp > 0) {
    final o = Offset(s.bossX, 320);
    c.drawOval(Rect.fromCenter(center: o, width: 260, height: 110), Paint()..color = const Color(0xFFD00000));
    c.drawOval(Rect.fromCenter(center: o.translate(0, -30), width: 120, height: 70), Paint()..color = const Color(0xFFFFBA08));
    final f = s.bossHp / s.bossMax;
    c.drawRect(Rect.fromLTWH(200, 160, 600, 18), Paint()..color = Colors.white24);
    c.drawRect(Rect.fromLTWH(200, 160, 600 * f, 18), Paint()..color = const Color(0xFFFF4D6D));
  }
  if (s.ufoX >= 0) {
    c.drawOval(Rect.fromCenter(center: Offset(s.ufoX, 150), width: 120, height: 40), Paint()..color = const Color(0xFFFF006E));
    c.drawOval(Rect.fromCenter(center: Offset(s.ufoX, 136), width: 50, height: 30), Paint()..color = Colors.white70);
  }
  if (s.level.shields) {
    for (var sh = 0; sh < 3; sh++) {
      for (var r = 0; r < InvadersSim.shieldRows; r++) {
        for (var col = 0; col < InvadersSim.shieldCols; col++) {
          final hp = s.shieldHp[(sh * InvadersSim.shieldRows + r) * InvadersSim.shieldCols + col];
          if (hp <= 0) continue;
          c.drawRect(
              Rect.fromLTWH(s.shieldX(sh) + col * InvadersSim.shieldBlock, InvadersSim.shieldY + r * InvadersSim.shieldBlock,
                  InvadersSim.shieldBlock - 2, InvadersSim.shieldBlock - 2),
              Paint()..color = Color(hp > 1 ? 0xFF52B788 : 0xFF2D6A4F));
        }
      }
    }
  }
  final shot = Paint()
    ..color = const Color(0xFFFFFF3F)
    ..strokeWidth = 6
    ..strokeCap = StrokeCap.round;
  for (final b in s.shots) {
    c.drawLine(Offset(b.x, b.y), Offset(b.x - b.vx, b.y + 22), shot);
  }
  final es = Paint()..color = const Color(0xFFFF4D6D);
  for (final b in s.enemyShots) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(b.x, b.y), width: 10, height: 26), const Radius.circular(5)), es);
  }
  for (final d in s.drops) {
    c.drawCircle(Offset(d.x, d.y), 24, Paint()..color = d.vx == 0 ? const Color(0xFF00BBF9) : const Color(0xFF9B5DE5));
    paintText(c, d.vx == 0 ? '»' : '⋔', Offset(d.x, d.y), 28, Colors.white);
  }
  // ship
  final ship = Path()
    ..moveTo(s.px, kPlayerY - 46)
    ..lineTo(s.px + 46, kPlayerY + 26)
    ..lineTo(s.px, kPlayerY + 10)
    ..lineTo(s.px - 46, kPlayerY + 26)
    ..close();
  final blink = s.shield > 0 && (s.ticks ~/ 5).isOdd;
  c.drawPath(ship, Paint()..color = blink ? Colors.white38 : p.piece(0));
  if (s.triple > 0 || s.rapid > 0) {
    c.drawCircle(Offset(s.px, kPlayerY), 60, Paint()
      ..color = Colors.white30
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3);
  }
}

Sfx? invadersSound(ArcadeSim sim) => switch ((sim as InvadersSim).lastEvent) {
      1 => Sfx.clear,
      3 => Sfx.tap,
      _ => null,
    };

final gameConfig = GameConfig(
  gameId: 'game-015-space-invaders-neo',
  title: const ['Uzay İstilacıları Neo', 'Space Invaders Neo', 'Weltraum-Invasoren Neo', 'Invasores Espaciales Neo', 'Envahisseurs Neo'],
  tagline: const ['Dünyayı dalga dalga savun!', 'Defend Earth wave after wave!', 'Verteidige die Erde Welle um Welle!', '¡Defiende la Tierra ola tras ola!', 'Défendez la Terre vague après vague !'],
  seedColor: const Color(0xFFF48C06),
  icon: Icons.rocket_launch,
  rules: InvadersRules(),
  buildPlay: (ctx) => ArcadeStage(
    ctx: ctx,
    create: () => InvadersSim((ctx.generated as GeneratedLevel<InvadersLevel>).puzzle),
    paint: paintInvaders,
    sound: invadersSound,
    boosterIcon: Icons.bolt,
    boosterLabel: (l) => l == 'tr' ? 'Süper ateş' : 'Super fire',
    howTo: const [
      'Gemiyi sürükle; otomatik ateş eder, dokununca ekstra atış.',
      'Drag the ship; it fires automatically, tap for extra shots.',
      'Schiff ziehen; es feuert automatisch.',
      'Arrastra la nave; dispara sola.',
      'Glissez le vaisseau ; il tire tout seul.',
    ],
  ),
  tutorial: const [
    TutorialStep(Icons.swipe, [
      'Gemiyi parmağınla sürükle (klavye: ←/→, boşluk: ateş).',
      'Drag the ship (keys ←/→, space fires).',
      'Schiff ziehen (←/→, Leertaste feuert).',
      'Arrastra la nave (←/→, espacio dispara).',
      'Glissez le vaisseau (←/→, espace tire).',
    ]),
    TutorialStep(Icons.shield, [
      'Kalkanların arkasına saklan; mermiler kalkanları aşındırır.',
      'Hide behind shields; shots wear them down.',
      'Versteck dich hinter Schilden.',
      'Escóndete tras los escudos.',
      'Cachez-vous derrière les boucliers.',
    ]),
    TutorialStep(Icons.star, [
      'UFO\'yu vur, güçlendirmeleri topla, son dalgada boss\'u yen.',
      'Shoot the UFO, grab power-ups, beat the boss on the last wave.',
      'Triff das UFO, besiege den Boss.',
      'Dispara al OVNI, vence al jefe.',
      'Touchez l\'OVNI, battez le boss.',
    ]),
  ],
);
