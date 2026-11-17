import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_015_space_invaders_neo/game/invader_engine.dart';

void main() {
  test('initial wave and reset are deterministic', () {
    final game = InvaderEngine();
    expect(game.invaders.length, 21);
    game.fire();
    game.tick(0.016);
    game.reset();
    expect(game.score, 0);
    expect(game.wave, 1);
    expect(game.shots, isEmpty);
    expect(game.invaders.length, 21);
  });

  test('player cannot leave playfield', () {
    final game = InvaderEngine();
    game.movePlayer(-100);
    expect(game.playerX, 18);
    game.movePlayer(10000);
    expect(game.playerX, 342);
  });

  test('shots are limited and pause freezes movement', () {
    final game = InvaderEngine();
    game.fire();
    game.fire();
    game.fire();
    expect(game.shots.length, 2);
    final before = game.shots.first;
    game.paused = true;
    game.tick(0.016);
    expect(game.shots.first, before);
    game.fire();
    expect(game.shots.length, 2);
  });

  test('a hit removes an invader and adds score', () {
    final game = InvaderEngine();
    game.invaders.clear();
    game.invaders.add(Point<double>(180, 100));
    game.shots.add(Point<double>(180, 107));
    game.tick(0.016);
    expect(game.score, 10);
    expect(game.wave, 2);
  });

  test('enemy reaching player ends game', () {
    final game = InvaderEngine();
    game.invaders.clear();
    game.invaders.add(Point<double>(180, 520));
    game.tick(0.016);
    expect(game.gameOver, isTrue);
    expect(game.lives, 0);
  });
}
