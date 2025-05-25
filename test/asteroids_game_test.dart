import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astroids/main.dart';
import 'package:flame/components.dart';

void main() {
  group('AsteroidsGame', () {
    testWithGame<AsteroidsGame>('initial score is zero', AsteroidsGame.new, (
      game,
    ) async {
      expect(game.score, 0);
    });

    testWithGame<AsteroidsGame>(
      'score increases when increaseScore is called',
      AsteroidsGame.new,
      (game) async {
        game.increaseScore(100);
        expect(game.score, 100);
      },
    );

    testWithGame<AsteroidsGame>('pause and resume flows', AsteroidsGame.new, (
      game,
    ) async {
      expect(game.isPaused, false);
      game.pauseGame();
      expect(game.isPaused, true);
      game.resumeGame();
      expect(game.isPaused, false);
    });

    testWithGame<AsteroidsGame>('tap actions (shooting)', AsteroidsGame.new, (
      game,
    ) async {
      // Simulate tap or shooting action
      // TODO: Implement tap/shoot logic and test it here
      // For now, just ensure the player exists
      expect(game.player, isA<PlayerShip>());
    });
  });
}
