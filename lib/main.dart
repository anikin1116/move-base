import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'services/auth_service.dart';
import 'providers/locale_provider.dart';
import 'screens/home/home_screen.dart';
import 'screens/search/search_screen.dart';
import 'screens/partner/partner_detail_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/dashboard/edit_profile_screen.dart';
import 'screens/legal/legal_screen.dart';
import 'screens/map/map_screen.dart';
import 'models/partner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    debugPrint('Firebase init skipped on this platform: $e');
  }
  runApp(const MoveBaseApp());
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
    GoRoute(
      path: '/partner/:id',
      builder: (_, state) =>
          PartnerDetailScreen(partnerId: state.pathParameters['id']!),
    ),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(
      path: '/edit-profile',
      builder: (_, state) =>
          EditProfileScreen(partner: state.extra as Partner),
    ),
    GoRoute(path: '/map', builder: (_, __) => const MapScreen()),
    GoRoute(path: '/agb', builder: (_, __) => const AgbScreen()),
    GoRoute(path: '/datenschutz', builder: (_, __) => const DatenschutzScreen()),
    GoRoute(path: '/impressum', builder: (_, __) => const ImpressumScreen()),
  ],
);

class MoveBaseApp extends StatefulWidget {
  const MoveBaseApp({super.key});

  @override
  State<MoveBaseApp> createState() => _MoveBaseAppState();
}

class _MoveBaseAppState extends State<MoveBaseApp> with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

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
    if (state == AppLifecycleState.paused) {
      _backgroundedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final bg = _backgroundedAt;
      if (bg != null &&
          DateTime.now().difference(bg).inMinutes >= 30) {
        _backgroundedAt = null;
        FirebaseAuth.instance.signOut();
        _router.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: Consumer<LocaleProvider>(
        builder: (_, localeProvider, __) => MaterialApp.router(
          title: 'MoveBase',
          theme: AppTheme.theme,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: const [Locale('de'), Locale('en')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
  }
}
