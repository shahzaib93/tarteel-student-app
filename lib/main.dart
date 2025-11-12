import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'services/webrtc_service.dart';
import 'services/app_config_service.dart';
import 'services/settings_service.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize app config from Firestore
  final appConfigService = AppConfigService();
  try {
    debugPrint('🔧 Initializing app config from Firestore...');
    await appConfigService.initialize();
    debugPrint('✅ App config initialized');
  } catch (e) {
    debugPrint('⚠️ Failed to initialize app config, using defaults: $e');
  }

  // Initialize settings service
  final settingsService = SettingsService();
  debugPrint('⚙️ Initializing settings...');
  await settingsService.initialize();
  debugPrint('✅ Settings initialized');

  runApp(TarteelStudentApp(
    appConfigService: appConfigService,
    settingsService: settingsService,
  ));
}

class TarteelStudentApp extends StatelessWidget {
  final AppConfigService appConfigService;
  final SettingsService settingsService;

  // Cannot use const because services are runtime values
  TarteelStudentApp({
    super.key,
    required this.appConfigService,
    required this.settingsService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppConfigService>.value(value: appConfigService),
        ChangeNotifierProvider<SettingsService>.value(value: settingsService),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(
          create: (_) {
            final webrtcService = WebRTCService();
            // Configure TURN server from Firestore config
            final turnConfig = appConfigService.getTurnConfig();
            if (turnConfig != null) {
              webrtcService.configureTurnServer(turnConfig);
            }
            // Link settings service to WebRTC
            webrtcService.setSettingsService(settingsService);
            return webrtcService;
          },
        ),
      ],
      child: MaterialApp(
        title: 'Tarteel Student',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF76a6f6),
            brightness: Brightness.light,
          ).copyWith(
            primary: const Color(0xFF76a6f6),
            secondary: const Color(0xFFa3c4f9),
            surface: Colors.white,
            background: Colors.white,
          ),
          scaffoldBackgroundColor: Colors.white,
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF76a6f6),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: const CardThemeData(
            elevation: 2,
            color: Colors.white,
          ),
          fontFamily: 'Inter',
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

/// Determines which screen to show based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    if (authService.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authService.currentUser != null) {
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}
