import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:restaurante_movil/providers/auth_provider.dart';
import 'package:restaurante_movil/providers/cart_provider.dart';
import 'package:restaurante_movil/screens/home_screen.dart';
import 'package:restaurante_movil/screens/login_screen.dart';
import 'package:restaurante_movil/screens/onboarding_screen.dart';
import 'package:restaurante_movil/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final prefs = await SharedPreferences.getInstance();
  final bool onboardingDone = prefs.getBool('onboarding_done') ?? false;
  final token = await AuthService.getToken();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MyApp(
        showOnboarding: !onboardingDone,
        isLoggedIn: token != null && token.isNotEmpty,
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool showOnboarding;
  final bool isLoggedIn;

  const MyApp({
    super.key,
    required this.showOnboarding,
    required this.isLoggedIn,
  });

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AuthProvider, ThemeMode>((a) => a.themeMode);

    return MaterialApp(
      title: 'Las Brazas Steakhouse',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFFAF9F7),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.light,
          seedColor: const Color(0xFFD85A1A),
          primary: const Color(0xFFD85A1A),
          secondary: const Color(0xFF22252A),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1E2025),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181A1F),
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFFE8832A),
          primary: const Color(0xFFE8832A),
          secondary: const Color(0xFFF3C68F),
          surface: const Color(0xFF22252C),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          backgroundColor: Color(0xFF1E2025),
          foregroundColor: Color(0xFFF5D0A9),
        ),
      ),
      home: showOnboarding
          ? const OnboardingScreen()
          : isLoggedIn
              ? const HomeScreen()
              : const LoginScreen(),
    );
  }
}
