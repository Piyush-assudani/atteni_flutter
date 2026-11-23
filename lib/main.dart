import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/main_screen.dart';
import 'screens/parent_portal_screen.dart';
import 'screens/parent_daily_topic_screen.dart';
import 'screens/parent_selection_screen.dart';
import 'screens/parent_login_screen.dart';
import 'screens/staff_portal_screen.dart';
import 'screens/staff_login_screen.dart';
import 'screens/gate_keeper_login_screen.dart';
import 'screens/changelog_screen.dart';
import 'screens/developer_profile_screen.dart';
import 'screens/offline_screen.dart';
import 'screens/faq_screen.dart';
import 'screens/task_manager_portal.dart';
import 'screens/task_manager_login_screen.dart';
import 'screens/admin_login_screen.dart';
import 'screens/admin_portal_screen.dart';
import 'services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'theme/app_theme.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  await NotificationService().checkFirstLaunch();
  await FirebaseService.initialize();
  
  // Setup Global Error Tracking (matching window.onerror in JS)
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    try {
      final crashId = DateTime.now().millisecondsSinceEpoch.toString();
      final dbPath = 'artifacts/student-system-v2/public/data'; 
      FirebaseDatabase.instance.ref('$dbPath/crashes/$crashId').set({
        'message': details.exceptionAsString(),
        'source': 'flutter',
        'error': details.stack?.toString(),
        'time': ServerValue.timestamp,
      });
    } catch (e) {
      // Silently fail if crash reporting fails
    }
  };

  runApp(const AtteniApp());
}

class AtteniApp extends StatelessWidget {
  const AtteniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atteni System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const BouncingScrollPhysics(),
        scrollbars: false,
      ),
      builder: (context, child) {
        return OfflineWrapper(child: child!);
      },
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/main': (context) => const MainScreen(),
        '/parent_login': (context) => const ParentLoginScreen(),
        '/parent_portal': (context) => const ParentPortalScreen(),
        '/parent_selection': (context) => const ParentSelectionScreen(),
        '/parent_daily_topics': (context) => const ParentDailyTopicScreen(),
        '/staff': (context) => const StaffPortalScreen(),
        '/staff_login': (context) => const StaffLoginScreen(),
        '/gatekeeper_login': (context) => const GateKeeperLoginScreen(),
        '/changelog': (context) => const ChangelogScreen(),
        '/developer_profile': (context) => const DeveloperProfileScreen(),
        '/offline': (context) => const OfflineScreen(),
        '/faq': (context) => const FaqScreen(),
        '/task_manager': (context) => const TaskManagerPortal(),
        '/task_manager_login': (context) => const TaskManagerLoginScreen(),
        '/admin_login': (context) => const AdminLoginScreen(),
        '/admin_portal': (context) => const AdminPortalScreen(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _revealAnimation;
  
  // Simulated network state based on the JS logic
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    
    // Exact match for animation: 2s cubic-bezier(0.42, 0, 0.1, 1) forwards;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _revealAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        // Using standard ease in out curve as closest standard approximation to the specific cubic-bezier
        curve: Curves.easeInOutCubic, 
      ),
    );

    _animationController.forward().then((_) {
      _doRedirect();
    });

    // In a full Flutter app, this would use the `connectivity_plus` package.
    // We start as online unless changed.
  }

  Future<void> _doRedirect() async {
    if (_isOffline) {
      // Logic matching JS: don't redirect if offline, wait for online event
      return;
    }
    
    debugPrint("Animation complete. Proceeding to navigation...");
    
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('userRole');
    
    if (!mounted) return;

    if (userRole == 'teacher' || prefs.getString('STAFF_ID') != null) {
      Navigator.of(context).pushReplacementNamed('/staff');
    } else if (userRole == 'parent' || prefs.getString('PARENT_MOBILE') != null) {
      Navigator.of(context).pushReplacementNamed('/parent_portal');
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background & Animated Text Layer
          Center(
            child: _buildAnimatedTitle(context),
          ),
          
          // Exact Match Offline Overlay
          if (_isOffline)
            _buildExactOfflineOverlay(),
        ],
      ),
    );
  }

  /// Builds the cursive "Atteni" text and handles the reveal animation
  Widget _buildAnimatedTitle(BuildContext context) {
    // Exact match for responsive text
    // font-size: 25vw; (up to 160px for min-width: 768px)
    double screenWidth = MediaQuery.of(context).size.width;
    double fontSize = screenWidth * 0.25; // 25vw
    if (screenWidth >= 768.0) {
      fontSize = 160.0;
    }

    return AnimatedBuilder(
      animation: _revealAnimation,
      builder: (context, child) {
        // ClipRect + Align mimics the exact `clip-path: inset(0 100% 0 0)` to `inset(0 0 0 0)`
        return ClipRect(
          child: Align(
            alignment: Alignment.centerLeft,
            widthFactor: _revealAnimation.value,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 20.0), // padding-right: 20px;
        child: Text(
          'Atteni',
          style: GoogleFonts.alexBrush(
            fontSize: fontSize,
            color: const Color(0xFF000000),
            fontWeight: FontWeight.normal,
            height: 1.0, // Ensures accurate line height matching CSS default
          ),
          maxLines: 1,
          softWrap: false, // white-space: nowrap;
        ),
      ),
    );
  }

  /// Exact 1:1 match for #offlineOverlay and .offline-tag
  Widget _buildExactOfflineOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF000000), // background: #000000;
        alignment: Alignment.center, // flex center
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'img.webp',
              width: 250,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0), // padding: 10px 20px;
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFFFFFFF), width: 2.0), // border: 2px solid #ffffff;
              ),
              child: const Text(
                'DISCONNECTED',
                style: TextStyle(
                  fontFamily: 'sans-serif',
                  color: Color(0xFFFFFFFF),
                  fontSize: 14.0, // font-size: 14px;
                  fontWeight: FontWeight.w700, // font-weight: 700;
                  letterSpacing: 12.0, // letter-spacing: 12px;
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
