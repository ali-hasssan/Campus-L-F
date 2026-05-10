import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'models/post_model.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/post_detail_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const CampusLFApp());
}

class CampusLFApp extends StatelessWidget {
  const CampusLFApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Campus L&F',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => const SignUpScreen(),
        '/profile-setup': (_) => const ProfileSetupScreen(),
        '/home': (_) => const HomeScreen(),
      },
      onGenerateRoute: (s) {
        if (s.name == '/post-detail') {
          return MaterialPageRoute(
            builder: (_) => PostDetailScreen(post: s.arguments as PostModel),
          );
        }
        if (s.name == '/create-post') {
          return MaterialPageRoute(
            builder: (_) => CreatePostScreen(post: s.arguments as PostModel?),
          );
        }
        return null;
      },
    );
  }
}

// App-wide constants
class AppK {
  static const categories = [
    'ID Card', 'Mobile', 'Bag', 'Keys', 'Wallet', 'Laptop', 'Other'
  ];
  static const areas = [
    'Library', 'Cafeteria', 'Main Block', 'Parking',
    'Sports Ground', 'Lab', 'Auditorium', 'Hostel', 'Other'
  ];
  static const departments = [
    'Computer Science', 'Information Technology', 'Software Engineering',
    'Electrical Engineering', 'Mechanical Engineering', 'Civil Engineering',
    'Business Administration', 'Other',
  ];
  static const semesters = [
    '1st', '2nd', '3rd', '4th', '5th', '6th', '7th', '8th'
  ];
}

// ─── Theme ─────────────────────────────────────────────────────────────────────
class AppTheme {
  static const primary   = Color(0xFF5B4FE9);
  static const lost      = Color(0xFFEF4444);
  static const found     = Color(0xFF10B981);
  static const bg        = Color(0xFFF5F5FA);
  static const surface   = Color(0xFFFFFFFF);
  static const txtPri    = Color(0xFF111827);
  static const txtSec    = Color(0xFF6B7280);
  static const border    = Color(0xFFE5E7EB);

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.fromSeed(seedColor: primary)
          .copyWith(surface: surface),
      textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: txtPri),
        titleTextStyle: GoogleFonts.poppins(
          color: txtPri, fontSize: 17, fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(color: primary, width: 2),
        errorBorder: _border(color: lost),
        focusedErrorBorder: _border(color: lost, width: 2),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.poppins(color: txtSec, fontSize: 14),
      ),
    );
  }

  static OutlineInputBorder _border({
    Color color = border,
    double width = 1,
  }) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}
