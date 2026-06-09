import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_routes.dart';

/// Which soothing track should be playing for a given screen.
enum _Track { none, ambient, loanFlow }

/// Centralised, route-aware background music controller.
///
/// Owns a single looping [AudioPlayer] and decides what should play based on
/// the active GoRouter path:
///   * Loan-submission / document-upload routes -> a calmer "loan_flow" track.
///   * Other post-login screens -> a gentle "ambient" track.
///   * Auth / splash screens (or when the user disabled music) -> silence.
///
/// This is purely additive: every audio call is guarded so a playback failure
/// can never crash the app or interfere with navigation, providers or uploads.
class AudioController with ChangeNotifier, WidgetsBindingObserver {
  AudioController({AudioPlayer? player})
      : _player = player ?? AudioPlayer(playerId: 'background_music');

  static const String _musicEnabledKey = 'background_music_enabled';
  static const double _volume = 0.3;

  static const String _ambientAsset = 'audio/ambient.mp3';
  static const String _loanFlowAsset = 'audio/loan_flow.mp3';

  /// Routes that belong to the loan-submission / document-upload flow.
  static final Set<String> _loanFlowRoutes = <String>{
    AppRoutes.instructions,
    AppRoutes.termsAndConditions,
    AppRoutes.businessLoanType,
    AppRoutes.professionalLoanType,
    AppRoutes.coApplicantChoice,
    AppRoutes.step1Selfie,
    AppRoutes.step2Aadhaar,
    AppRoutes.step3Pan,
    AppRoutes.step4SpouseAadhaar,
    AppRoutes.step5SpousePan,
    AppRoutes.step4BankStatement,
    AppRoutes.coApplicantAadhaar,
    AppRoutes.coApplicantPan,
    AppRoutes.coApplicantBankStatement,
    AppRoutes.coApplicantSalarySlips,
    AppRoutes.coApplicantFirmDocs,
    AppRoutes.coApplicantFirmKyc,
    AppRoutes.step5PersonalData,
    AppRoutes.step5_1SalarySlips,
    AppRoutes.step5BusinessDocs,
    AppRoutes.step5ProfessionalDocs,
    AppRoutes.step5StudentDocs,
    AppRoutes.step5PropertyDetails,
    AppRoutes.step6Msme,
    AppRoutes.step7Ohp,
    AppRoutes.step6Preview,
    AppRoutes.partnerCount,
    AppRoutes.partnerAadhaar,
    AppRoutes.partnerPan,
  };

  /// Routes where no music should play (pre-login / splash).
  static final Set<String> _silentRoutes = <String>{
    AppRoutes.splash,
    AppRoutes.onboarding,
    AppRoutes.login,
    AppRoutes.forgotPassword,
  };

  final AudioPlayer _player;

  bool _initialized = false;
  bool _musicEnabled = true;
  bool _appActive = true;
  String _currentPath = AppRoutes.splash;
  _Track _currentTrack = _Track.none;

  /// Whether the user has background music turned on.
  bool get musicEnabled => _musicEnabled;

  /// Loads the persisted preference and configures the player. Safe to call
  /// once at app start; never throws.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    } catch (_) {
      _musicEnabled = true;
    }
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
    } catch (_) {
      // Ignore – playback simply won't start.
    }
    WidgetsBinding.instance.addObserver(this);
  }

  /// Called whenever the active route changes.
  void onRouteChanged(String path) {
    _currentPath = path;
    _syncPlayback();
  }

  /// Toggles music on/off, persists the choice and updates playback.
  Future<void> setMusicEnabled(bool value) async {
    if (_musicEnabled == value) return;
    _musicEnabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_musicEnabledKey, value);
    } catch (_) {
      // Preference persistence failure should not affect playback.
    }
    _syncPlayback();
  }

  _Track _trackForPath(String path) {
    if (_silentRoutes.contains(path)) return _Track.none;
    if (_loanFlowRoutes.contains(path)) return _Track.loanFlow;
    return _Track.ambient;
  }

  /// Resolves what should be playing right now and reconciles the player.
  void _syncPlayback() {
    final desired = (!_musicEnabled || !_appActive)
        ? _Track.none
        : _trackForPath(_currentPath);

    if (desired == _currentTrack) return;
    _currentTrack = desired;

    if (desired == _Track.none) {
      _safeStop();
    } else {
      _safePlay(desired == _Track.ambient ? _ambientAsset : _loanFlowAsset);
    }
  }

  Future<void> _safePlay(String asset) async {
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(_volume);
      await _player.play(AssetSource(asset));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AudioController: failed to play $asset -> $e');
      }
    }
  }

  Future<void> _safeStop() async {
    try {
      await _player.stop();
    } catch (_) {
      // Ignore.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (active == _appActive) return;
    _appActive = active;
    if (!active) {
      _pauseForBackground();
    } else {
      _resumeFromBackground();
    }
  }

  Future<void> _pauseForBackground() async {
    if (_currentTrack == _Track.none) return;
    try {
      await _player.pause();
    } catch (_) {
      // Ignore.
    }
  }

  Future<void> _resumeFromBackground() async {
    // If music was disabled or the route changed while backgrounded, let the
    // normal sync logic pick the correct state.
    final desired =
        _musicEnabled ? _trackForPath(_currentPath) : _Track.none;
    if (desired == _currentTrack && desired != _Track.none) {
      try {
        await _player.resume();
      } catch (_) {
        // Fall back to a full re-sync if resume fails.
        _currentTrack = _Track.none;
        _syncPlayback();
      }
    } else {
      _currentTrack = _Track.none;
      _syncPlayback();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    try {
      _player.dispose();
    } catch (_) {
      // Ignore.
    }
    super.dispose();
  }
}
