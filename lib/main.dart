import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flame/collisions.dart';
import 'audio_manager.dart';

void main() {
  runApp(
    MaterialApp(
      home: Stack(
        children: [
          GameWidget(
            game: AsteroidsGame(),
            overlayBuilderMap: {
              'ScoreOverlay': (context, AsteroidsGame game) =>
                  ScoreOverlay(game: game),
              'PauseOverlay': (context, AsteroidsGame game) =>
                  PauseOverlay(game: game),
              'GameOverOverlay': (context, AsteroidsGame game) =>
                  GameOverOverlay(game: game),
            },
          ),
          // Touch controls overlay (always present on mobile)
          Builder(
            builder: (context) {
              final isMobile = MediaQuery.of(context).size.shortestSide < 600;
              return isMobile
                  ? TouchControls(game: AsteroidsGame())
                  : const SizedBox.shrink();
            },
          ),
        ],
      ),
    ),
  );
}

/// The main Asteroids game class.
class AsteroidsGame extends FlameGame
    with HasKeyboardHandlerComponents, HasCollisionDetection {
  late PlayerShip player;
  late AudioManager audioManager;
  int score = 0;
  int highScore = 0; // Session-based high score
  int lives = 3;
  bool isPaused = false;
  bool gameOver = false;
  bool respawning = false;
  double invincibilityTime = 2.0;
  final Random _random = Random();
  // Touch control state
  bool touchLeft = false;
  bool touchRight = false;
  bool touchThrust = false;
  bool touchShoot = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Initialize audio manager
    audioManager = AudioManager();
    await audioManager.initialize();
    await audioManager.startBackgroundMusic();
    
    // Add starfield background
    add(Starfield(numStars: 100));
    
    // Add player ship
    player = PlayerShip();
    add(player);
    // Spawn initial asteroids
    for (int i = 0; i < 5; i++) {
      spawnAsteroid();
    }
    // Show score overlay
    overlays.add('ScoreOverlay');
  }

  void spawnAsteroid({Vector2? position, double? size, Vector2? velocity}) {
    final screen = this.size;
    final pos =
        position ??
        Vector2(
          _random.nextDouble() * screen.x,
          _random.nextDouble() * screen.y,
        );
    final sz = size ?? (_random.nextDouble() * 40 + 30); // 30-70 px
    final angle = _random.nextDouble() * pi * 2;
    final speed = _random.nextDouble() * 60 + 40; // 40-100 px/sec
    final vel = velocity ?? Vector2(cos(angle), sin(angle)) * speed;
    add(Asteroid(position: pos, size: sz, velocity: vel));
  }

  void increaseScore(int value) {
    score += value;
    if (score > highScore) {
      highScore = score;
    }
    // Score overlay will update automatically
  }

  void pauseGame() {
    isPaused = true;
    pauseEngine();
    audioManager.pauseBackgroundMusic();
    overlays.add('PauseOverlay');
  }

  void resumeGame() {
    isPaused = false;
    resumeEngine();
    audioManager.startBackgroundMusic();
    overlays.remove('PauseOverlay');
  }

  void gameOverSequence() {
    gameOver = true;
    pauseEngine();
    audioManager.stopBackgroundMusic();
    audioManager.playGameOver();
    overlays.add('GameOverOverlay');
  }

  void loseLife() {
    lives--;
    if (lives > 0) {
      respawnPlayer();
    } else {
      gameOverSequence();
    }
  }

  void respawnPlayer() async {
    respawning = true;
    player.removeFromParent();
    await Future.delayed(const Duration(seconds: 1));
    player = PlayerShip(invincible: true);
    add(player);
    // Invincibility for 2 seconds
    await Future.delayed(
      Duration(milliseconds: (invincibilityTime * 1000).toInt()),
    );
    player.setInvincible(false);
    respawning = false;
  }

  void restartGame() {
    children.whereType<Asteroid>().forEach((a) => a.removeFromParent());
    children.whereType<Bullet>().forEach((b) => b.removeFromParent());
    player.position = size / 2;
    player.velocity = Vector2.zero();
    player.angle = 0;
    score = 0;
    lives = 3;
    gameOver = false;
    overlays.remove('GameOverOverlay');
    overlays.add('ScoreOverlay');
    resumeEngine();
    audioManager.startBackgroundMusic();
    for (int i = 0; i < 5; i++) {
      spawnAsteroid();
    }
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    // Toggle pause/resume with 'P' key
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyP) {
      if (!gameOver) {
        if (isPaused) {
          resumeGame();
        } else {
          pauseGame();
        }
      }
      return KeyEventResult.handled;
    }
    return super.onKeyEvent(event, keysPressed);
  }

  @override
  void onRemove() {
    audioManager.dispose();
    super.onRemove();
  }
}

/// The player's ship.
class PlayerShip extends PositionComponent
    with HasGameRef<AsteroidsGame>, KeyboardHandler, CollisionCallbacks {
  // Ship movement properties
  Vector2 velocity = Vector2.zero();
  double rotationSpeed = 3.0; // radians per second
  double thrust = 200.0; // acceleration per second
  bool turningLeft = false;
  bool turningRight = false;
  bool accelerating = false;
  bool shooting = false;
  double shootCooldown = 0.2; // seconds between shots
  double shootTimer = 0.0;
  bool invincible;
  double invincibleTimer = 0.0;
  bool _blink = false;
  bool thrustSoundPlaying = false;

  PlayerShip({this.invincible = false})
    : super(size: Vector2(40, 40), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    position = gameRef.size / 2;
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw a triangle for the ship
    double localOpacity = 1.0;
    if (invincible) {
      if ((invincibleTimer * 8).floor() % 2 == 0) {
        localOpacity = 0.3;
      }
    }
    final paint = Paint()
      ..color = (invincible ? Colors.yellow : Colors.white).withOpacity(
        localOpacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final shipSize = size.y / 2;
    final points = [
      Vector2(0, -shipSize),
      Vector2(shipSize * 0.7, shipSize * 0.7),
      Vector2(-shipSize * 0.7, shipSize * 0.7),
    ];
    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final p = (points[i].clone()..rotate(angle)) + size / 2;
      if (i == 0) {
        path.moveTo(p.x, p.y);
      } else {
        path.lineTo(p.x, p.y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void setInvincible(bool value) {
    invincible = value;
    // No direct opacity property, handled in render
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (invincible) {
      invincibleTimer += dt;
    } else {
      invincibleTimer = 0.0;
    }
    // Handle rotation
    if (turningLeft || gameRef.touchLeft) {
      angle -= rotationSpeed * dt;
    }
    if (turningRight || gameRef.touchRight) {
      angle += rotationSpeed * dt;
    }
    // Handle thrust
    if (accelerating || gameRef.touchThrust) {
      applyThrust(dt);
    } else {
      thrustSoundPlaying = false;
    }
    // Apply velocity to position
    position += velocity * dt;
    // Screen wrap
    final screen = gameRef.size;
    if (position.x < 0) position.x += screen.x;
    if (position.x > screen.x) position.x -= screen.x;
    if (position.y < 0) position.y += screen.y;
    if (position.y > screen.y) position.y -= screen.y;
    // Apply friction
    velocity *= 0.99;

    // Shooting logic
    if (shooting || gameRef.touchShoot) {
      shootTimer -= dt;
      if (shootTimer <= 0) {
        shoot();
        shootTimer = shootCooldown;
      }
    } else {
      shootTimer = 0;
    }
  }

  void applyThrust(double dt) {
    if (!accelerating) {
      accelerating = true;
      gameRef.audioManager.playThrust();
    }
    final thrustVector = Vector2(cos(angle), sin(angle)) * dt * thrust;
    velocity.add(thrustVector);
  }

  void shoot() {
    if (shootTimer <= 0) {
      final bulletVelocity = Vector2(cos(angle), sin(angle)) * 500;
      final bulletPosition = position.clone();
      gameRef.add(Bullet(position: bulletPosition, velocity: bulletVelocity));
      gameRef.audioManager.playShoot();
      shootTimer = shootCooldown;
    }
  }

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    // Keyboard controls: left/right/up arrows
    turningLeft = keysPressed.contains(LogicalKeyboardKey.arrowLeft);
    turningRight = keysPressed.contains(LogicalKeyboardKey.arrowRight);
    accelerating = keysPressed.contains(LogicalKeyboardKey.arrowUp);
    shooting = keysPressed.contains(LogicalKeyboardKey.space);
    return true;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (!invincible) {
      if (other is Asteroid) {
        gameRef.audioManager.playExplosion();
        removeFromParent();
        gameRef.loseLife();
      }
    }
  }
}

class Bullet extends CircleComponent
    with HasGameRef<AsteroidsGame>, CollisionCallbacks {
  static const double speed = 400.0;
  Vector2 velocity;
  double life = 2.0; // seconds
  Bullet({required Vector2 position, required this.velocity})
    : super(
        radius: 3,
        position: position,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFFFFFFF),
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(CircleHitbox());
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * speed * dt;
    // Screen wrap
    final screen = gameRef.size;
    if (position.x < 0) position.x += screen.x;
    if (position.x > screen.x) position.x -= screen.x;
    if (position.y < 0) position.y += screen.y;
    if (position.y > screen.y) position.y -= screen.y;
    life -= dt;
    if (life <= 0) {
      removeFromParent();
    }
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Asteroid) {
      // Play explosion sound
      if (radius > 30) {
        gameRef.audioManager.playExplosion();
      }
      // Increase score
      gameRef.increaseScore(100);
      // Split asteroid if large
      if (radius > 25) {
        for (int i = 0; i < 2; i++) {
          final newSize = radius;
          final angle = gameRef._random.nextDouble() * pi * 2;
          final speed = gameRef._random.nextDouble() * 80 + 40;
          final vel = Vector2(cos(angle), sin(angle)) * speed;
          gameRef.spawnAsteroid(
            position: position.clone(),
            size: newSize,
            velocity: vel,
          );
        }
      }
      removeFromParent();
      other.removeFromParent();
    }
    if (other is PlayerShip) {
      // Player hit: game over
      gameRef.gameOverSequence();
    }
  }
}

class Asteroid extends PositionComponent
    with HasGameRef<AsteroidsGame>, CollisionCallbacks {
  Vector2 velocity;
  double minSize = 25.0;
  List<Vector2> shape = [];
  double radius;

  Asteroid({
    required Vector2 position,
    required double size,
    required this.velocity,
  }) : radius = size / 2,
       super(
         position: position,
         anchor: Anchor.center,
         size: Vector2.all(size),
       );

  @override
  Future<void> onLoad() async {
    // Generate a random jagged polygon shape
    final points = <Vector2>[];
    final sides = 8 + gameRef._random.nextInt(4); // 8-11 sides
    for (int i = 0; i < sides; i++) {
      final angle = (i / sides) * 2 * pi;
      final r =
          radius *
          (0.7 + gameRef._random.nextDouble() * 0.5); // 70%-120% of radius
      points.add(Vector2(cos(angle), sin(angle)) * r + size / 2);
    }
    shape = points;
    add(PolygonHitbox(points.map((p) => p - size / 2).toList()));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final paint = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path();
    for (int i = 0; i < shape.length; i++) {
      final p = shape[i];
      if (i == 0) {
        path.moveTo(p.x, p.y);
      } else {
        path.lineTo(p.x, p.y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;
    final screen = gameRef.size;
    if (position.x < 0) position.x += screen.x;
    if (position.x > screen.x) position.x -= screen.x;
    if (position.y < 0) position.y += screen.y;
    if (position.y > screen.y) position.y -= screen.y;
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    super.onCollision(intersectionPoints, other);
    if (other is Bullet) {
      // Play explosion sound
      if (radius > 30) {
        gameRef.audioManager.playExplosion();
      }
      // Increase score
      gameRef.increaseScore(100);
      // Split asteroid if large
      if (radius > minSize) {
        for (int i = 0; i < 2; i++) {
          final newSize = radius;
          final angle = gameRef._random.nextDouble() * pi * 2;
          final speed = gameRef._random.nextDouble() * 80 + 40;
          final vel = Vector2(cos(angle), sin(angle)) * speed;
          gameRef.spawnAsteroid(
            position: position.clone(),
            size: newSize,
            velocity: vel,
          );
        }
      }
      removeFromParent();
      other.removeFromParent();
    }
    if (other is PlayerShip) {
      // Player hit: game over
      gameRef.gameOverSequence();
    }
  }
}

// Score overlay widget
class ScoreOverlay extends StatelessWidget {
  final AsteroidsGame game;
  const ScoreOverlay({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score: ${game.score}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'High Score: ${game.highScore}',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 32),
              Row(
                children: List.generate(
                  game.lives,
                  (index) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.favorite, color: Colors.red, size: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Pause overlay widget
class PauseOverlay extends StatelessWidget {
  final AsteroidsGame game;
  const PauseOverlay({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                game.resumeGame();
              },
              child: const Text('Resume'),
            ),
          ],
        ),
      ),
    );
  }
}

// Game over overlay widget
class GameOverOverlay extends StatelessWidget {
  final AsteroidsGame game;
  const GameOverOverlay({super.key, required this.game});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Game Over',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Final Score: ${game.score}',
              style: const TextStyle(color: Colors.white, fontSize: 20),
            ),
            Text(
              'High Score: ${game.highScore}',
              style: const TextStyle(
                color: Colors.amber,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                game.restartGame();
              },
              child: const Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }
}

class TouchControls extends StatelessWidget {
  final AsteroidsGame game;
  const TouchControls({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final buttonSize = 64.0;
    final padding = 16.0;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Left
          _TouchButton(
            icon: Icons.rotate_left,
            onPressed: () => game.touchLeft = true,
            onReleased: () => game.touchLeft = false,
            size: buttonSize,
          ),
          // Thrust
          _TouchButton(
            icon: Icons.arrow_upward,
            onPressed: () => game.touchThrust = true,
            onReleased: () => game.touchThrust = false,
            size: buttonSize,
          ),
          // Shoot
          _TouchButton(
            icon: Icons.circle,
            onPressed: () => game.touchShoot = true,
            onReleased: () => game.touchShoot = false,
            size: buttonSize,
          ),
          // Right
          _TouchButton(
            icon: Icons.rotate_right,
            onPressed: () => game.touchRight = true,
            onReleased: () => game.touchRight = false,
            size: buttonSize,
          ),
        ],
      ),
    );
  }
}

class _TouchButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final VoidCallback onReleased;
  final double size;
  const _TouchButton({
    required this.icon,
    required this.onPressed,
    required this.onReleased,
    required this.size,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: () => onReleased(),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.7),
      ),
    );
  }
}

// Starfield background component
class Starfield extends Component {
  final int numStars;
  final List<_Star> stars = [];
  final Random _random = Random();
  Vector2? _screenSize;

  Starfield({this.numStars = 100});

  @override
  Future<void> onLoad() async {
    _screenSize = (parent as FlameGame).size;
    for (int i = 0; i < numStars; i++) {
      stars.add(
        _Star(
          position: Vector2(
            _random.nextDouble() * _screenSize!.x,
            _random.nextDouble() * _screenSize!.y,
          ),
          speed: 10 + _random.nextDouble() * 40,
          radius: 0.5 + _random.nextDouble() * 1.5,
          twinkle: _random.nextDouble(),
        ),
      );
    }
  }

  @override
  void update(double dt) {
    if (_screenSize == null) return;
    for (final star in stars) {
      star.position.y += star.speed * dt;
      if (star.position.y > _screenSize!.y) {
        star.position.y = 0;
        star.position.x = _random.nextDouble() * _screenSize!.x;
      }
      // Twinkle
      star.twinkle += dt * 0.5;
      if (star.twinkle > 1) star.twinkle -= 1;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_screenSize == null) return;
    for (final star in stars) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(
          0.5 + 0.5 * sin(star.twinkle * 2 * pi),
        );
      canvas.drawCircle(
        Offset(star.position.x, star.position.y),
        star.radius,
        paint,
      );
    }
  }
}

class _Star {
  Vector2 position;
  double speed;
  double radius;
  double twinkle;
  _Star({
    required this.position,
    required this.speed,
    required this.radius,
    required this.twinkle,
  });
}
