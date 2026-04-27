import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

class AudioConsultantService {
  AudioConsultantService._();

  static final AudioConsultantService instance = AudioConsultantService._();

  static const String _languageCodeKey = 'audio_consultant_language_code';
  static const String _enabledKey = 'audio_consultant_mode_enabled';

  final FlutterTts _tts = FlutterTts();

  bool _initialized = false;
  bool _isConsultantModeEnabled = true;
  String _languageCode = 'fil-PH';

  bool get isConsultantModeEnabled => _isConsultantModeEnabled;
  String get languageCode => _languageCode;

  Future<void> initialize() async {
    if (_initialized) return;

    await _loadPreferences();

    // Local Android engine; ignored gracefully on platforms where unavailable.
    await _safeTtsCall(() => _tts.setEngine('com.google.android.tts'));
    await _safeTtsCall(() => _tts.awaitSpeakCompletion(true));
    await _safeTtsCall(() => _tts.setPitch(0.7));
    await _safeTtsCall(() => _tts.setSpeechRate(0.9));
    await _safeTtsCall(() => _tts.setLanguage(_languageCode));

    String engineLang = _languageCode == 'ilo-PH' ? 'fil-PH' : _languageCode;
    await _safeTtsCall(() => _tts.setLanguage(engineLang));

    _initialized = true;
  }

  Future<void> setConsultantModeEnabled(bool enabled) async {
    _isConsultantModeEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, enabled);

    if (!enabled) {
      await _safeTtsCall(() => _tts.stop());
    }
  }

  Future<void> setLanguageCode(String code) async {
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, code);
    await _safeTtsCall(() => _tts.setLanguage(code));

    String engineLang = code == 'ilo-PH' ? 'fil-PH' : code;
    await _safeTtsCall(() => _tts.setLanguage(engineLang));
  }

  Future<void> playHealthyFeedback() async {
    if (!await _canOutput()) return;

    await _vibrateIfAvailable(
      duration: 80,
      amplitude: 80,
    );

    await _speak(_localizedHealthyText());
  }

  Future<void> playDiseaseWarning(String diseaseName) async {
    if (!await _canOutput()) return;

    // Three sharp pulses.
    await _vibratePatternIfAvailable(
      pattern: [0, 120, 70, 120, 70, 120],
      intensities: [0, 255, 0, 255, 0, 255],
    );

    final safeDiseaseName = diseaseName.trim().isEmpty ? 'hindi matukoy' : diseaseName.trim();
    await _speak(_localizedDiseaseWarning(safeDiseaseName));
  }

  Future<void> playWeatherAdvisory(String advisoryText) async {
    if (!await _canOutput()) return;

    // Standard notification-like pattern.
    await _vibratePatternIfAvailable(
      pattern: [0, 160, 90, 200],
      intensities: [0, 180, 0, 180],
    );

    final text = advisoryText.trim().isEmpty ? _localizedWeatherFallback() : advisoryText.trim();
    await _speak(text);
  }

  Future<void> playTreatmentGuide(String treatmentSteps) async {
    if (!await _canOutput()) return;
    final text = treatmentSteps.trim();
    if (text.isEmpty) return;

    await _safeTtsCall(() => _tts.setSpeechRate(0.35));
    try {
      await _speak(text);
    } finally {
      await _safeTtsCall(() => _tts.setSpeechRate(0.4));
    }
  }

  Future<void> stop() async {
    await _safeTtsCall(() => _tts.stop());
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString(_languageCodeKey) ?? 'fil-PH';
    _isConsultantModeEnabled = prefs.getBool(_enabledKey) ?? true;
  }

  Future<bool> _canOutput() async {
    await initialize();
    return _isConsultantModeEnabled;
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    await _safeTtsCall(() => _tts.speak(text));
  }

  Future<void> _vibrateIfAvailable({
    required int duration,
    int? amplitude,
  }) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    if (amplitude == null) {
      await Vibration.vibrate(duration: duration);
      return;
    }
    await Vibration.vibrate(duration: duration, amplitude: amplitude);
  }

  Future<void> _vibratePatternIfAvailable({
    required List<int> pattern,
    List<int>? intensities,
  }) async {
    final hasVibrator = await Vibration.hasVibrator();
    if (!hasVibrator) return;
    if (intensities == null) {
      await Vibration.vibrate(pattern: pattern);
      return;
    }
    await Vibration.vibrate(pattern: pattern, intensities: intensities);
  }

  Future<void> _safeTtsCall(Future<dynamic> Function() call) async {
    try {
      await call();
    } catch (_) {
      // Keep service resilient when engine/language support varies by device.
    }
  }

  String _localizedHealthyText() {
    switch (_languageCode) {
      case 'en-US':
        return 'Tree is healthy.';
      case 'ilo-PH':
        return 'Nasalun-at ti kayo.';
      case 'fil-PH':
      default:
        return 'Puno ay malusog.';
    }
  }

  String _localizedDiseaseWarning(String diseaseName) {
    switch (_languageCode) {
      case 'en-US':
        return 'Warning: Disease detected: $diseaseName.';
      case 'ilo-PH':
        return 'Babala: Adda nakita a sakit nga $diseaseName.';
      case 'fil-PH':
      default:
        return 'Babala: May nakitang sakit na $diseaseName.';
    }
  }

  String _localizedWeatherFallback() {
    switch (_languageCode) {
      case 'en-US':
        return 'Weather advisory detected. Please check your farm conditions.';
      case 'ilo-PH':
        return 'Adda weather advisory. Pangngaasiyo ta kitaen ti kasasaad ti talonyo.';
      case 'fil-PH':
      default:
        return 'May weather advisory. Pakisuri ang kalagayan ng inyong taniman.';
    }
  }
}
