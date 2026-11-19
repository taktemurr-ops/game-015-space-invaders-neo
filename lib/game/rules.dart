import '../core/arcade.dart';
import '../core/level_plan.dart';
import '../core/missions.dart';
import '../core/stats.dart';
import 'invaders_engine.dart';

class InvadersRules extends ArcadeRules<InvadersLevel> {
  @override
  String get gameId => 'game-015-space-invaders-neo';

  @override
  List<String> get optionalMechanics => const ['armored', 'divers', 'ufo', 'boss', 'no_shields'];

  @override
  List<GameStat> get gameStats => const [
        GameStat('aliens_destroyed', 'Yok edilen uzaylı', 'Aliens destroyed', scale: 200),
        GameStat('waves_cleared', 'Temizlenen dalga', 'Waves cleared', scale: 10),
        GameStat('ufos', 'Bonus UFO', 'UFOs', scale: 3),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('aliens_destroyed', 'aliens_destroyed', [66, 133, 200]),
        MissionTemplate('waves_cleared', 'waves_cleared', [3, 6, 10]),
      ];

  @override
  InvadersLevel generate(LevelSpec spec) => generateInvadersLevel(spec);

  @override
  ArcadeMeta metaOf(InvadersLevel l) => l.meta;

  @override
  ArcadeSim createSim(InvadersLevel l) => InvadersSim(l);

  @override
  ArcadeInput bot(ArcadeSim sim) => invadersBot(sim);
}

ArcadeRules createRules() => InvadersRules();
