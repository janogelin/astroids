# Astroids (Classic Asteroids Game in Flutter with Flame)

Astroids is a recreation of the classic arcade game Asteroids, built using the [Flame](https://flame-engine.org/) game engine for Flutter. It features responsive controls, sound effects, scoring, and robust testing using `flame_test` and Flutter's integration testing tools.

## Features
- Classic Asteroids gameplay: shoot asteroids, avoid collisions, and rack up your score!
- Responsive keyboard and tap controls
- Sound effects from `assets/audio/`
- Pause and resume functionality
- Score tracking and UI overlays
- Extensive unit and integration tests

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.8.0)

### Setup
1. Clone the repository:
   ```sh
   git clone <repo-url>
   cd astroids
   ```
2. Fetch dependencies:
   ```sh
   flutter pub get
   ```
3. Run the game:
   ```sh
   flutter run
   ```

## Game Controls
- **Move Ship:** Arrow keys or on-screen controls (to be implemented)
- **Shoot:** Spacebar or tap/click (to be implemented)
- **Pause/Resume:** P key or pause button (to be implemented)

## Sound Assets
All sound effects are located in `assets/audio/` and are loaded at runtime using `flame_audio`.

## Testing
### Unit and Widget Tests
- Run all tests:
  ```sh
  flutter test
  ```
- Tests are located in the `test/` directory and use `flame_test` for game-specific assertions.

### Integration Tests
- Integration tests will be located in the `integration_test/` directory.
- Run integration tests:
  ```sh
  flutter test integration_test
  ```

## Project Structure
- `lib/` - Main game code (Flame game, components, logic)
- `assets/audio/` - Sound assets
- `test/` - Unit and widget tests
- `integration_test/` - Integration tests

## Contributing
Pull requests are welcome! Please add tests for new features and ensure all tests pass before submitting.

## License
[MIT](LICENSE)
