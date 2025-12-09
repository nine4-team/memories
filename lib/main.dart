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
    // Simple, minimal neutral palette inspired by Notion/Linear
    // Using soft grays with very subtle warm undertone
    return MaterialApp(
      title: 'Memories',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor:
            const Color(0xFFF5F5F5), // Neutral gray - matches capture screen
        colorScheme: const ColorScheme.light(
          brightness: Brightness.light,
          primary: Color(0xFF2B2B2B), // Dark gray for buttons
          onPrimary: Color(0xFFFFFFFF),
          primaryContainer: Color(0xFFE8E8E8), // Light gray
          onPrimaryContainer: Color(0xFF2B2B2B),
          secondary: Color(0xFF525252),
          onSecondary: Color(0xFFFFFFFF),
          secondaryContainer: Color(0xFFE8E8E8),
          onSecondaryContainer: Color(0xFF2B2B2B),
          tertiary: Color(0xFF525252),
          onTertiary: Color(0xFFFFFFFF),
          tertiaryContainer: Color(0xFFE8E8E8),
          onTertiaryContainer: Color(0xFF2B2B2B),
          error: Color(0xFFDC2626), // Tailwind red-600
          onError: Color(0xFFFFFFFF),
          errorContainer: Color(0xFFFEE2E2),
          onErrorContainer: Color(0xFF7F1D1D),
          surface: Color(0xFFFFFFFF), // White for cards and surfaces
          onSurface: Color(0xFF171717), // Near-black text
          surfaceContainerHighest:
              Color(0xFFFFFFFF), // White for elevated containers
          onSurfaceVariant: Color(0xFF525252), // Medium gray for secondary text
          surfaceVariant: Color(0xFFF0F0F0), // Light gray for input backgrounds
          outline: Color(0xFFD4D4D4), // Light border
          outlineVariant: Color(0xFFE5E5E5),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFF2B2B2B),
          onInverseSurface: Color(0xFFF5F5F5),
          inversePrimary: Color(0xFFA3A3A3),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFFFFFFF), // Explicitly white cards
          elevation: 1,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF5F5F5), // Match scaffold background
          elevation: 0,
          scrolledUnderElevation: 0, // Disable scroll-based elevation change
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFFF5F5F5), // Match scaffold background
          indicatorColor: Colors.transparent, // Remove pill background
          overlayColor: MaterialStateProperty.resolveWith((states) {
            // Disable all overlay effects (pressed, hovered, focused)
            return Colors.transparent;
          }),
          iconTheme: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const IconThemeData(
                color: Color(0xFF2B2B2B), // Dark gray for selected icons
              );
            }
            return const IconThemeData(
              color: Color(0xFF8A8A8A), // Lighter gray for unselected
            );
          }),
          labelTextStyle: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const TextStyle(
                color: Color(0xFF2B2B2B),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              );
            }
            return const TextStyle(
              color: Color(0xFF8A8A8A),
              fontWeight: FontWeight.normal,
              fontSize: 12,
            );
          }),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2B2B2B), // Use primary color
            foregroundColor: const Color(0xFFFFFFFF), // White text
            elevation: 2,
            disabledBackgroundColor: const Color(0xFFE5E5E5),
            disabledForegroundColor: const Color(0xFFA3A3A3),
          ),
        ),
      ),
      themeMode: ThemeMode.light, // Force light mode for now
      // Keep the dark theme config around in comments for future revisiting.
      /*
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(
          brightness: Brightness.dark,
          primary: Color(0xFFA3A3A3), // Light gray for dark mode
          onPrimary: Color(0xFF1F1F1F),
          primaryContainer: Color(0xFF3A3A3A),
          onPrimaryContainer: Color(0xFFE5E5E5),
          secondary: Color(0xFFA3A3A3),
          onSecondary: Color(0xFF1F1F1F),
          secondaryContainer: Color(0xFF3A3A3A),
          onSecondaryContainer: Color(0xFFE5E5E5),
          tertiary: Color(0xFFA3A3A3),
          onTertiary: Color(0xFF1F1F1F),
          tertiaryContainer: Color(0xFF3A3A3A),
          onTertiaryContainer: Color(0xFFE5E5E5),
          error: Color(0xFFFCA5A5), // Tailwind red-300
          onError: Color(0xFF450A0A),
          errorContainer: Color(0xFF7F1D1D),
          onErrorContainer: Color(0xFFFEE2E2),
          surface: Color(0xFF1A1A1A),
          onSurface: Color(0xFFA3A3A3), // Medium gray for text/icons
          surfaceContainerHighest: Color(0xFF2B2B2B),
          onSurfaceVariant: Color(0xFF8A8A8A),
          surfaceVariant: Color(0xFF2B2B2B),
          outline: Color(0xFF404040),
          outlineVariant: Color(0xFF2B2B2B),
          shadow: Color(0xFF000000),
          scrim: Color(0xFF000000),
          inverseSurface: Color(0xFFE5E5E5),
          onInverseSurface: Color(0xFF2B2B2B),
          inversePrimary: Color(0xFF525252),
        ),
      ),
      */
      home: const AppRouter(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/password-reset': (context) => const PasswordResetScreen(),
      },
    );
  }
}
