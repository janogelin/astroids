import 'package:flame_test/flame_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:astroids/main.dart';
import 'package:astroids/audio_manager.dart';
import 'package:flame/game.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AsteroidsGame', () {
    late AsteroidsGame game;

    setUp(() async {
      // Set up test environment for audio
      AudioManager().setTestEnvironment(true);
      
      game = AsteroidsGame();
      // Register overlay builders
      game.overlays.addEntry(
        'ScoreOverlay',
        (context, game) => ScoreOverlay(game: game as AsteroidsGame),
      );
      game.overlays.addEntry(
        'PauseOverlay',
        (context, game) => PauseOverlay(game: game as AsteroidsGame),
      );
      game.overlays.addEntry(
        'GameOverOverlay',
        (context, game) => GameOverOverlay(game: game as AsteroidsGame),
      );
      // Set game size
      game.onGameResize(Vector2(800, 600));
      // Initialize game
      await game.onLoad();
    });

    test('initial score is zero', () {
      expect(game.score, equals(0));
    });

    test('score increases when increaseScore is called', () {
      game.increaseScore(100);
      expect(game.score, equals(100));
    });

    test('pause and resume flows', () {
      expect(game.isPaused, isFalse);
      game.pauseGame();
      expect(game.isPaused, isTrue);
      game.resumeGame();
      expect(game.isPaused, isFalse);
    });

    test('shooting state changes', () {
      expect(game.player.shooting, isFalse);
      game.player.shooting = true;
      expect(game.player.shooting, isTrue);
    });
  });
}
