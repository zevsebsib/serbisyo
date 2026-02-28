import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:serbisyo_alisto/firebase_options.dart';
import 'package:serbisyo_alisto/screens/alerts_demo_screen.dart';
import 'package:serbisyo_alisto/screens/dashboard_screen.dart';
import 'package:serbisyo_alisto/screens/edit_profile_screen.dart';
import 'package:serbisyo_alisto/screens/forgot_password_screen.dart';
import 'package:serbisyo_alisto/screens/history_screen.dart';
import 'package:serbisyo_alisto/screens/login_screen.dart';
import 'package:serbisyo_alisto/screens/notifications_screen.dart';
import 'package:serbisyo_alisto/screens/personal_information_screen.dart';
import 'package:serbisyo_alisto/screens/profile_screen.dart';
import 'package:serbisyo_alisto/screens/register_screen.dart';
import 'package:serbisyo_alisto/screens/request_tracking_screen.dart';
import 'package:serbisyo_alisto/screens/service_category_detail_screen.dart';
import 'package:serbisyo_alisto/screens/service_form_screen.dart';
import 'package:serbisyo_alisto/screens/services_screen.dart';
import 'package:serbisyo_alisto/screens/splash_screen.dart';
import 'package:serbisyo_alisto/screens/status_screen.dart';
import 'package:serbisyo_alisto/screens/submission_receipt_screen.dart';
import 'package:serbisyo_alisto/screens/support_screen.dart';
import 'package:serbisyo_alisto/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Force portrait and integrate status bar color
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((_) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    runApp(const SerbisyoAlistoApp());
  });
}

class SerbisyoAlistoApp extends StatefulWidget {
  const SerbisyoAlistoApp({super.key});

  @override
  State<SerbisyoAlistoApp> createState() => _SerbisyoAlistoAppState();
}

class _SerbisyoAlistoAppState extends State<SerbisyoAlistoApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  String? _currentRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _currentRoute != '/splash') {
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/splash', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'SerbisyoAlisto',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      initialRoute: '/splash',
      onGenerateRoute: (settings) {
        _currentRoute = settings.name;
        Widget page;
        switch (settings.name) {
          case '/splash':
            page = const SplashScreen();
            break;
          case '/login':
            page = const LoginScreen();
            break;
          case '/register':
            page = const RegisterScreen();
            break;
          case '/forgot_password':
            page = const ForgotPasswordScreen();
            break;
          case '/':
            page = const DashboardScreen();
            break;
          case '/services':
            page = const ServicesScreen();
            break;
          case '/service_detail':
            final args = settings.arguments as Map<String, dynamic>?;
            page = ServiceCategoryDetailScreen(categoryId: args?['categoryId'] ?? 'mayor');
            break;
          case '/service_form':
            final args = settings.arguments as Map<String, dynamic>?;
            page = ServiceFormScreen(serviceName: args?['serviceName']);
            break;
          case '/notifications':
            page = const NotificationsScreen();
            break;
          case '/alerts':
            page = const AlertsDemoScreen();
            break;
          case '/profile':
            page = const ProfileScreen();
            break;
          case '/profile_info':
            page = const PersonalInformationScreen();
            break;
          case '/profile_edit':
            page = const EditProfileScreen();
            break;
          case '/profile_history':
            page = const HistoryScreen();
            break;
          case '/profile_help':
            page = const SupportScreen();
            break;
          case '/profile_settings':
            page = const SupportScreen(); // Placeholder
            break;
          case '/status_success':
            page = const StatusScreen(isSuccess: true);
            break;
          case '/status_failed':
            page = const StatusScreen(isSuccess: false);
            break;
          case '/requests/receipt':
            page = const SubmissionReceiptScreen();
            break;
          case '/requests/track':
            page = const RequestTrackingScreen();
            break;
          default:
            page = const NotFoundScreen();
        }

        // Use non-directional transition to avoid horizontal offset artifacts
        if (settings.name == '/splash') {
          return PageRouteBuilder(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (context, anim, secAnim) => page,
          );
        }

        return PageRouteBuilder(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 220),
          reverseTransitionDuration: const Duration(milliseconds: 180),
          pageBuilder: (context, anim, secAnim) => page,
          transitionsBuilder: (context, anim, secAnim, child) {
            final fadeAnimation = CurvedAnimation(
              parent: anim,
              curve: Curves.easeOut,
            );

            return FadeTransition(
              opacity: fadeAnimation,
              child: child,
            );
          },
        );
      },
    );
  }
}

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Page Not Found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/'),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
