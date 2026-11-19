import 'package:flutter_test/flutter_test.dart';
import 'package:game_015_space_invaders_neo/core/arcade.dart';
import 'package:game_015_space_invaders_neo/core/level_plan.dart';
import 'package:game_015_space_invaders_neo/game/invaders_engine.dart';
import 'package:game_015_space_invaders_neo/game/rules.dart';

void main() {
  final rules = InvadersRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('a player shot destroys the alien it reaches', () {
    final s = InvadersSim(rules.build(planner.spec(1)).puzzle);
    final before = s.enemies.length;
    final e = s.enemies.last;
    s.shots.add(Shot(s.ex(e), s.ey(e) + 40, 0, -24));
    s.tick(ArcadeInput.idle);
    expect(s.enemies.length, before - 1);
    expect(s.kills, 1);
  });

  test('enemy shot costs a life and shields absorb shots', () {
    final s = InvadersSim(rules.build(planner.spec(1)).puzzle);
    s.enemyShots.add(Shot(s.px, kPlayerY - 20, 0, 5));
    s.tick(ArcadeInput.idle);
    expect(s.lives, 2);
    final hp = s.shieldHp.fold<int>(0, (a, b) => a + b);
    s.enemyShots.add(Shot(s.shieldX(0) + 10, InvadersSim.shieldY - 2, 0, 5));
    s.tick(ArcadeInput.idle);
    s.tick(ArcadeInput.idle);
    expect(s.shieldHp.fold<int>(0, (a, b) => a + b), lessThan(hp));
  });

  test('boss levels end with a boss wave', () {
    final l = rules.build(planner.spec(10)).puzzle;
    expect(l.boss, isTrue);
    expect(l.totalWaves, l.waves + 1);
  });
}
