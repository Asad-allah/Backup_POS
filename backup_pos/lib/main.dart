import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme/theme_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/cart_provider.dart';
import 'providers/product_provider.dart';
import 'providers/transaction_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/expiration_provider.dart';

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProductProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),

        ChangeNotifierProvider(create: (_) => TransactionProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => ExpirationProvider()),
      ],
      child: const BackupPosApp(),
    ),
  );
}

class BackupPosApp extends StatelessWidget {
  const BackupPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sheikh Al Jabal POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme, // Apply the new theme
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    // Delay slightly for splash effect
    await Future.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      // Loading / Splash
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return _isLoggedIn! ? const HomeScreen() : const LoginScreen();
  }
}
