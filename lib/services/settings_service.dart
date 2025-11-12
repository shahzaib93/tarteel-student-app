import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService with ChangeNotifier {
  static const String _hdVideoKey = 'hd_video_enabled';
  static const String _micDefaultKey = 'microphone_default_on';
  static const String _cameraDefaultKey = 'camera_default_on';

  bool _hdVideo = true;
  bool _microphoneDefault = true;
  bool _cameraDefault = true;
  bool _isInitialized = false;

  bool get hdVideo => _hdVideo;
  bool get microphoneDefault => _microphoneDefault;
  bool get cameraDefault => _cameraDefault;
  bool get isInitialized => _isInitialized;

  /// Initialize settings from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _hdVideo = prefs.getBool(_hdVideoKey) ?? true;
      _microphoneDefault = prefs.getBool(_micDefaultKey) ?? true;
      _cameraDefault = prefs.getBool(_cameraDefaultKey) ?? true;

      debugPrint('⚙️ Settings loaded: HD=$_hdVideo, Mic=$_microphoneDefault, Cam=$_cameraDefault');
    } catch (e) {
      debugPrint('❌ Error loading settings, using defaults: $e');
      // Use default values if loading fails
      _hdVideo = true;
      _microphoneDefault = true;
      _cameraDefault = true;
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Update HD video setting
  Future<void> setHdVideo(bool value) async {
    _hdVideo = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hdVideoKey, value);
      debugPrint('✅ HD Video setting saved: $value');
    } catch (e) {
      debugPrint('❌ Error saving HD video setting: $e');
    }
  }

  /// Update microphone default setting
  Future<void> setMicrophoneDefault(bool value) async {
    _microphoneDefault = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_micDefaultKey, value);
      debugPrint('✅ Microphone default setting saved: $value');
    } catch (e) {
      debugPrint('❌ Error saving microphone setting: $e');
    }
  }

  /// Update camera default setting
  Future<void> setCameraDefault(bool value) async {
    _cameraDefault = value;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_cameraDefaultKey, value);
      debugPrint('✅ Camera default setting saved: $value');
    } catch (e) {
      debugPrint('❌ Error saving camera setting: $e');
    }
  }

  /// Get video constraints based on HD setting
  Map<String, dynamic> getVideoConstraints() {
    if (_hdVideo) {
      return {
        'facingMode': 'user',
        'width': {'ideal': 1280},
        'height': {'ideal': 720},
        'frameRate': {'ideal': 30},
      };
    } else {
      return {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 480},
        'frameRate': {'ideal': 15},
      };
    }
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _hdVideo = true;
    _microphoneDefault = true;
    _cameraDefault = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hdVideoKey, true);
      await prefs.setBool(_micDefaultKey, true);
      await prefs.setBool(_cameraDefaultKey, true);
      debugPrint('✅ Settings reset to defaults');
    } catch (e) {
      debugPrint('❌ Error resetting settings: $e');
    }
  }
}
