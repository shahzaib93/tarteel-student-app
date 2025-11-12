import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AppConfigService {
  static const String _configCollection = 'appConfig';
  static const String _configDocument = 'webrtc';
  static const String _cacheKey = 'flutter_student_app_config';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, dynamic>? _currentConfig;

  // Default fallback configuration
  static const Map<String, dynamic> _defaultConfig = {
    'socketUrl': 'http://192.95.33.150:5003',
    'apiBaseUrl': 'http://192.95.33.150:5003/api',
    'appEnv': 'production',
  };

  /// Initialize app config from Firestore
  Future<Map<String, dynamic>> initialize() async {
    debugPrint('🔧 Initializing app config...');

    try {
      // Try to fetch from Firestore
      final firestoreConfig = await _fetchConfigFromFirestore();

      if (firestoreConfig != null) {
        debugPrint('✅ Using Firestore config');
        _currentConfig = _buildConfig(firestoreConfig);
        await _cacheConfig(_currentConfig!);
        return _currentConfig!;
      }
    } catch (error) {
      debugPrint('❌ Failed to load config from Firestore: $error');
    }

    // Fallback to cache
    try {
      final cached = await _loadConfigFromCache();
      if (cached != null) {
        debugPrint('📦 Using cached config');
        _currentConfig = cached;
        return _currentConfig!;
      }
    } catch (error) {
      debugPrint('⚠️ Failed to load cached config: $error');
    }

    // Final fallback to defaults
    debugPrint('⚙️ Using default config');
    _currentConfig = _buildConfig(_defaultConfig);
    return _currentConfig!;
  }

  /// Fetch config from Firestore
  Future<Map<String, dynamic>?> _fetchConfigFromFirestore() async {
    debugPrint('📡 Fetching app config from Firestore...');

    try {
      final docRef = _firestore.collection(_configCollection).doc(_configDocument);
      final snapshot = await docRef.get().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Firestore fetch timeout (10s)');
        },
      );

      if (!snapshot.exists) {
        debugPrint('⚠️ App config document not found in Firestore');
        return null;
      }

      final data = snapshot.data();
      debugPrint('✅ App config loaded from Firestore');
      return data;
    } catch (e) {
      debugPrint('❌ Error fetching config from Firestore: $e');
      rethrow;
    }
  }

  /// Build normalized config
  Map<String, dynamic> _buildConfig(Map<String, dynamic> partial) {
    final turnConfig = _normalizeTurnConfig(
      partial['turn'] ?? partial['turnConfig'] ?? partial['turnServer'],
    );

    return {
      'apiBaseUrl': partial['apiBaseUrl'] ?? partial['apiUrl'] ?? _defaultConfig['apiBaseUrl'],
      'socketUrl': partial['socketUrl'] ?? partial['signalingUrl'] ?? _defaultConfig['socketUrl'],
      'appEnv': partial['appEnv'] ?? partial['environment'] ?? _defaultConfig['appEnv'],
      'turn': turnConfig,
      'updatedAt': partial['updatedAt'],
    };
  }

  /// Normalize TURN server config
  Map<String, dynamic>? _normalizeTurnConfig(dynamic turn) {
    if (turn == null) return null;

    Map<String, dynamic> turnMap;

    // Handle array format
    if (turn is List && turn.isNotEmpty) {
      turnMap = turn.first is Map ? Map<String, dynamic>.from(turn.first) : {};
    } else if (turn is Map) {
      turnMap = Map<String, dynamic>.from(turn);
    } else {
      return null;
    }

    // Extract values
    final host = turnMap['host'] as String?;
    final port = turnMap['port'] as int? ?? 3478;
    final username = turnMap['username'] as String? ?? turnMap['user'] as String?;
    final credential = turnMap['credential'] as String? ?? turnMap['password'] as String?;

    // Handle urls field
    List<String> urls = [];
    if (turnMap['urls'] != null) {
      if (turnMap['urls'] is List) {
        urls = (turnMap['urls'] as List).map((e) => e.toString()).toList();
      } else if (turnMap['urls'] is String) {
        urls = [turnMap['urls'] as String];
      }
    }

    // Generate URLs from host if not provided
    if (urls.isEmpty && host != null) {
      urls = [
        'turn:$host:$port',
        'turn:$host:$port?transport=tcp',
      ];
    }

    return {
      'host': host,
      'port': port,
      'username': username,
      'credential': credential,
      'urls': urls,
    };
  }

  /// Cache config to local storage
  Future<void> _cacheConfig(Map<String, dynamic> config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'config': config,
        'cachedAt': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (e) {
      debugPrint('⚠️ Failed to cache app config: $e');
    }
  }

  /// Load config from cache
  Future<Map<String, dynamic>?> _loadConfigFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);

      if (raw == null) return null;

      final parsed = jsonDecode(raw);
      if (parsed != null && parsed['config'] != null) {
        return Map<String, dynamic>.from(parsed['config']);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to parse cached app config: $e');
    }

    return null;
  }

  /// Get current config
  Map<String, dynamic> getConfig() {
    return _currentConfig ?? _buildConfig(_defaultConfig);
  }

  /// Get socket URL
  String getSocketUrl() {
    final config = getConfig();
    return config['socketUrl'] as String? ?? _defaultConfig['socketUrl'] as String;
  }

  /// Get TURN server config
  Map<String, dynamic>? getTurnConfig() {
    final config = getConfig();
    return config['turn'] as Map<String, dynamic>?;
  }

  /// Listen for real-time config updates
  Stream<Map<String, dynamic>> listenForUpdates() {
    return _firestore
        .collection(_configCollection)
        .doc(_configDocument)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        debugPrint('🔄 App config updated from Firestore');
        final newConfig = _buildConfig(snapshot.data()!);
        _currentConfig = newConfig;
        _cacheConfig(newConfig);
        return newConfig;
      }
      return getConfig();
    });
  }
}
