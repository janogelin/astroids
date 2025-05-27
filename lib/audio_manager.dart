import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

class AudioManager {
  static final AudioManager _instance = AudioManager._internal();
  factory AudioManager() => _instance;
  AudioManager._internal();

  final AudioPlayer _shootPlayer = AudioPlayer();
  final AudioPlayer _explosionPlayer = AudioPlayer();
  final AudioPlayer _thrustPlayer = AudioPlayer();
  final AudioPlayer _gameOverPlayer = AudioPlayer();
  final AudioPlayer _backgroundMusicPlayer = AudioPlayer();

  bool _isSoundEnabled = true;
  bool _isMusicEnabled = true;
  double _soundVolume = 1.0;
  double _musicVolume = 0.5;

  bool _isInitialized = false;
  bool _isTestEnvironment = false;

  // For testing purposes
  void setTestEnvironment(bool value) {
    _isTestEnvironment = value;
    _isInitialized = value;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      if (!_isTestEnvironment) {
        await Future.wait([
          _initAudioPlayer(_shootPlayer, 'assets/audio/shoot.mp3', 'shoot'),
          _initAudioPlayer(_explosionPlayer, 'assets/audio/explosion.mp3', 'explosion'),
          _initAudioPlayer(_thrustPlayer, 'assets/audio/thrust.mp3', 'thrust'),
          _initAudioPlayer(_gameOverPlayer, 'assets/audio/game_over.mp3', 'game over'),
          _initAudioPlayer(_backgroundMusicPlayer, 'assets/audio/background_music.mp3', 'background music'),
        ]);

        // Set background music to loop
        await _backgroundMusicPlayer.setLoopMode(LoopMode.one);
        await _backgroundMusicPlayer.setVolume(_musicVolume);
      }
      
      _isInitialized = true;
      debugPrint('AudioManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AudioManager: $e');
      // Continue without audio rather than crashing
      _isInitialized = true;
    }
  }

  Future<void> _initAudioPlayer(AudioPlayer player, String assetPath, String name) async {
    try {
      await player.setAsset(assetPath);
      debugPrint('Loaded audio asset: $name');
    } catch (e) {
      debugPrint('Failed to load audio asset $name: $e');
    }
  }

  Future<void> playShoot() async {
    if (!_isSoundEnabled || !_isInitialized || _isTestEnvironment) return;
    try {
      await _shootPlayer.seek(Duration.zero);
      await _shootPlayer.setVolume(_soundVolume);
      await _shootPlayer.play();
    } catch (e) {
      debugPrint('Error playing shoot sound: $e');
    }
  }

  Future<void> playExplosion() async {
    if (!_isSoundEnabled || !_isInitialized || _isTestEnvironment) return;
    try {
      await _explosionPlayer.seek(Duration.zero);
      await _explosionPlayer.setVolume(_soundVolume);
      await _explosionPlayer.play();
    } catch (e) {
      debugPrint('Error playing explosion sound: $e');
    }
  }

  Future<void> playThrust() async {
    if (!_isSoundEnabled || !_isInitialized || _isTestEnvironment) return;
    try {
      await _thrustPlayer.seek(Duration.zero);
      await _thrustPlayer.setVolume(_soundVolume);
      await _thrustPlayer.play();
    } catch (e) {
      debugPrint('Error playing thrust sound: $e');
    }
  }

  Future<void> playGameOver() async {
    if (!_isSoundEnabled || !_isInitialized || _isTestEnvironment) return;
    try {
      await _gameOverPlayer.seek(Duration.zero);
      await _gameOverPlayer.setVolume(_soundVolume);
      await _gameOverPlayer.play();
    } catch (e) {
      debugPrint('Error playing game over sound: $e');
    }
  }

  Future<void> startBackgroundMusic() async {
    if (!_isMusicEnabled || !_isInitialized || _isTestEnvironment) return;
    try {
      await _backgroundMusicPlayer.seek(Duration.zero);
      await _backgroundMusicPlayer.play();
    } catch (e) {
      debugPrint('Error playing background music: $e');
    }
  }

  Future<void> stopBackgroundMusic() async {
    if (!_isInitialized || _isTestEnvironment) return;
    try {
      await _backgroundMusicPlayer.stop();
    } catch (e) {
      debugPrint('Error stopping background music: $e');
    }
  }

  Future<void> pauseBackgroundMusic() async {
    if (!_isInitialized || _isTestEnvironment) return;
    try {
      await _backgroundMusicPlayer.pause();
    } catch (e) {
      debugPrint('Error pausing background music: $e');
    }
  }

  void toggleSound() {
    _isSoundEnabled = !_isSoundEnabled;
    debugPrint('Sound ${_isSoundEnabled ? 'enabled' : 'disabled'}');
  }

  void toggleMusic() {
    _isMusicEnabled = !_isMusicEnabled;
    if (_isMusicEnabled) {
      startBackgroundMusic();
    } else {
      stopBackgroundMusic();
    }
    debugPrint('Music ${_isMusicEnabled ? 'enabled' : 'disabled'}');
  }

  void setSoundVolume(double volume) {
    _soundVolume = volume.clamp(0.0, 1.0);
    debugPrint('Sound volume set to $_soundVolume');
  }

  void setMusicVolume(double volume) {
    _musicVolume = volume.clamp(0.0, 1.0);
    if (_isInitialized && !_isTestEnvironment) {
      _backgroundMusicPlayer.setVolume(_musicVolume);
    }
    debugPrint('Music volume set to $_musicVolume');
  }

  Future<void> dispose() async {
    if (!_isInitialized || _isTestEnvironment) return;
    try {
      await Future.wait([
        _shootPlayer.dispose(),
        _explosionPlayer.dispose(),
        _thrustPlayer.dispose(),
        _gameOverPlayer.dispose(),
        _backgroundMusicPlayer.dispose(),
      ]);
      debugPrint('AudioManager disposed successfully');
    } catch (e) {
      debugPrint('Error disposing AudioManager: $e');
    }
  }
} 