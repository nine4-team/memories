import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:memories/app_router.dart';
import 'package:memories/screens/auth/login_screen.dart';
import 'package:memories/screens/auth/signup_screen.dart';
import 'package:memories/screens/auth/password_reset_screen.dart';
import 'package:memories/services/supabase_secure_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Load environment variables from .env file
    await dotenv.load(fileName: '.env');
    
    // Verify .env loaded correctly
    final url = dotenv.env['SUPABASE_URL'];
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    
    if (url == null || url.isEmpty || key == null || key.isEmpty) {
      throw StateError(
        'Failed to load Supabase credentials from .env file. '
        'Make sure SUPABASE_URL and SUPABASE_ANON_KEY are set.',
      );
    }
    
    debugPrint('✓ Loaded Supabase URL: ${url.substring(0, 30)}...');
    
    // Initialize Supabase with secure storage for OAuth PKCE flow
    await Supabase.initialize(
      url: url,
      anonKey: key,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        localStorage: SupabaseSecureStorage(),
      ),
    );
    
    debugPrint('✓ Supabase initialized with secure storage');
  } catch (e, stackTrace) {
    debugPrint('ERROR initializing app: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memories',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const AppRouter(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/password-reset': (context) => const PasswordResetScreen(),
      },
    );
  }
}
