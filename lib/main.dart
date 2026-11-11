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
    return MaterialApp(
      title: 'Restaurante Las Brazas',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          secondary: Colors.deepPurple,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
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
