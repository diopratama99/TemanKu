import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data/app_database.dart';
import 'services/auth_service.dart';
import 'services/launch_action_service.dart';
import 'state/auth_notifier.dart';
import 'state/theme_notifier.dart';
import 'pages/login_page.dart';
import 'pages/welcome_page.dart';
import 'pages/home_page.dart';
import 'pages/add_transaction_page.dart';
import 'pages/categories_page.dart';
import 'pages/profile_page.dart';
import 'pages/account_transfers_page.dart';
import 'pages/import_export_page.dart';
import 'pages/transactions_page.dart';
import 'pages/budgets_page.dart';
import 'pages/savings_page.dart';
import 'pages/trend_analysis_page.dart';
import 'pages/monthly_comparison_page.dart';
import 'pages/voice_add_transaction_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('id_ID', null);
  await AppDatabase().init();
  final launchActionService = LaunchActionService();
  await launchActionService.initialize();
  runApp(MyApp(launchActionService: launchActionService));
}

class MyApp extends StatefulWidget {
  final LaunchActionService launchActionService;

  const MyApp({super.key, required this.launchActionService});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _db = AppDatabase();
  final _auth = AuthService();
  late Future<void> _init;
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _init = _auth.loadSession();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: _db),
        Provider<GlobalKey<NavigatorState>>.value(value: _navigatorKey),
        ChangeNotifierProvider<LaunchActionService>.value(
          value: widget.launchActionService,
        ),
        ChangeNotifierProvider<AuthNotifier>(
          create: (_) => AuthNotifier(_auth),
        ),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'TemanKu',
            navigatorKey: _navigatorKey,
            theme: AppTheme.theme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeNotifier.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              return _LaunchActionListener(
                child: child ?? const SizedBox.shrink(),
              );
            },
            routes: {
              '/welcome': (_) => const WelcomePage(),
              '/login': (_) => const LoginPage(),
              '/add': (_) => const AddTransactionPage(),
              '/categories': (_) => const CategoriesPage(),
              '/profile': (_) => const ProfilePage(),
              '/accounts': (_) => const AccountTransfersPage(),
              '/import': (_) => const ImportExportPage(),
              '/transactions': (_) => const TransactionsPage(),
              '/budgets': (_) => const BudgetsPage(),
              '/savings': (_) => const SavingsPage(),
              '/trend_analysis': (_) => const TrendAnalysisPage(),
              '/monthly_comparison': (_) => const MonthlyComparisonPage(),
            },
            home: FutureBuilder<void>(
              future: _init,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final auth = context.watch<AuthNotifier>();
                if (!auth.isLoggedIn) {
                  return const LoginPage();
                }
                return _WelcomeGate(userId: auth.userId);
              },
            ),
          );
        },
      ),
    );
  }
}

/// Decides between [WelcomePage] (first time for this user) and [HomePage]
/// by checking the per-user `welcome_seen_<userId>` flag.
class _WelcomeGate extends StatelessWidget {
  final String? userId;
  const _WelcomeGate({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: WelcomePage.hasSeen(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final seen = snapshot.data ?? false;
        return seen ? const HomePage() : const WelcomePage();
      },
    );
  }
}

class _LaunchActionListener extends StatefulWidget {
  final Widget child;

  const _LaunchActionListener({required this.child});

  @override
  State<_LaunchActionListener> createState() => _LaunchActionListenerState();
}

class _LaunchActionListenerState extends State<_LaunchActionListener> {
  bool _handling = false;
  LaunchActionService? _service;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextService = context.read<LaunchActionService>();
    if (!identical(_service, nextService)) {
      _service?.removeListener(_onLaunchActionChanged);
      _service = nextService;
      _service?.addListener(_onLaunchActionChanged);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingAction());
  }

  @override
  void dispose() {
    _service?.removeListener(_onLaunchActionChanged);
    super.dispose();
  }

  void _onLaunchActionChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingAction());
  }

  Future<void> _handlePendingAction() async {
    if (!mounted || _handling) return;

    final service = context.read<LaunchActionService>();
    final action = service.pendingAction;
    if (action == null) return;

    final auth = context.read<AuthNotifier>();
    if (!auth.isLoggedIn) return;

    final hasSeenWelcome = await WelcomePage.hasSeen(auth.userId);
    if (!mounted || !hasSeenWelcome) return;

    final navigatorKey = context.read<GlobalKey<NavigatorState>>();
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final consumed = service.consumeAction();
    if (consumed == null) return;

    _handling = true;
    try {
      switch (consumed) {
        case LaunchAction.openVoiceTransaction:
          await navigator.push(
            MaterialPageRoute<bool>(
              builder: (_) => const VoiceAddTransactionPage(),
              fullscreenDialog: true,
            ),
          );
      }
    } finally {
      _handling = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AuthNotifier>();
    context.watch<LaunchActionService>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _handlePendingAction());
    return widget.child;
  }
}

// AuthNotifier moved to state/auth_notifier.dart
