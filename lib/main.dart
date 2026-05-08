import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'screens/splash_screen.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'screens/onboarding_screen.dart';
import 'providers/app_state_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/smart_alarm_screen.dart';
import 'screens/schedule_planner_screen.dart';
import 'screens/productivity_screen.dart';
import 'screens/meeting_assistant_screen.dart';
import 'screens/ai_chat_screen.dart';
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Later: read message.data and update local alarm notification if needed.
}
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);

FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

await FirebaseMessaging.instance.requestPermission();
  tz.initializeTimeZones();
  try {
    final timeZoneInfo = await FlutterTimezone.getLocalTimezone();
    final String timeZoneName = timeZoneInfo.identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e) {
    // Fallback if timezone cannot be obtained
    tz.setLocalLocation(tz.getLocation('UTC'));
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: const TimePilotApp(),
    ),
  );
}

class TimePilotApp extends StatelessWidget {
  const TimePilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppStateProvider>().isDarkMode;

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp(
          title: 'TimePilot AI',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashScreen(
            nextScreen: AppEntryGate(),
          ),
        );
      },
    );
  }
}
class AppEntryGate extends StatelessWidget {
  const AppEntryGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppStateProvider>(
      builder: (context, state, _) {
        if (!state.isProfileLoaded) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (!state.hasCompletedOnboarding) {
          return const OnboardingScreen();
        }

        return const MainNavigationScreen();
      },
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedMessageSub;
  Timer? _autoTrafficTimer;

  @override
  void initState() {
    super.initState();

    // 1. App-open automatic traffic check every 1 minute.
    _autoTrafficTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        context.read<AppStateProvider>().autoCheckTrafficIfDue(context);
      },
    );

    // 2. When FCM arrives while app is open.
    _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;

      context
          .read<AppStateProvider>()
          .applyBackendTrafficShiftFromFcm(message.data);
    });

    // 3. When user taps notification and app opens.
    _openedMessageSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!mounted) return;

      context
          .read<AppStateProvider>()
          .applyBackendTrafficShiftFromFcm(message.data);
    });

    // 4. If app was killed and opened from notification.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();

      if (!mounted || initialMessage == null) return;

      context
          .read<AppStateProvider>()
          .applyBackendTrafficShiftFromFcm(initialMessage.data);
    });
  }

  @override
  void dispose() {
    _foregroundMessageSub?.cancel();
    _openedMessageSub?.cancel();
    _autoTrafficTimer?.cancel();
    super.dispose();
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> screens = [
  DashboardScreen(
    onNavigate: (index) {
      setState(() {
        _currentIndex = index;
      });
    },
  ),
  const SmartAlarmScreen(),
  const SchedulePlannerScreen(),
  const ProductivityScreen(),
  const MeetingAssistantScreen(),
  const AIChatScreen(),
];
    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        selectedItemColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
        unselectedItemColor: isDark ? Colors.white54 : Colors.black54,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.alarm), label: 'Alarm'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Planner'),
          BottomNavigationBarItem(icon: Icon(Icons.insights), label: 'Focus'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Meeting'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble), label: 'AI Chat'),
        ],
      ),
    );
  }
}
