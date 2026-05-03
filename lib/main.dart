import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data/app_database.dart';
import 'services/auth_service.dart';
import 'services/launch_action_service.dart';
import 'services/notification_listener_service.dart';
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
import 'pages/receipt_ocr_page.dart';
import 'pages/debts_page.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('id_ID', null);
  await AppDatabase().init();
  final launchActionService = LaunchActionService();
  await launchActionService.initialize();
  final notificationListenerService = NotificationListenerService();
  notificationListenerService.initialize();
  runApp(MyApp(
    launchActionService: launchActionService,
    notificationListenerService: notificationListenerService,
  ));
}

class MyApp extends StatefulWidget {
  final LaunchActionService launchActionService;
  final NotificationListenerService notificationListenerService;

  const MyApp({
    super.key,
    required this.launchActionService,
    required this.notificationListenerService,
  });

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
        ChangeNotifierProvider<NotificationListenerService>.value(
          value: widget.notificationListenerService,
        ),
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
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final overlayStyle = isDark
                  ? SystemUiOverlayStyle.light.copyWith(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      // iOS status text color counterpart.
                      statusBarBrightness: Brightness.dark,
                    )
                  : SystemUiOverlayStyle.dark.copyWith(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.dark,
                      // iOS status text color counterpart.
                      statusBarBrightness: Brightness.light,
                    );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlayStyle,
                child: _LaunchActionListener(
                  child: child ?? const SizedBox.shrink(),
                ),
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
              '/debts': (_) => const DebtsPage(),
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

  /// Tracks the route pushed by a widget action so we can remove it
  /// before pushing a different one (prevents stacking).
  Route<dynamic>? _activeWidgetRoute;

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
      // Pop any existing widget-launched route before pushing new one.
      // This prevents stacking multiple voice/camera pages on top of
      // each other when the user rapidly taps different widget icons.
      if (_activeWidgetRoute != null) {
        navigator.removeRoute(_activeWidgetRoute!);
        _activeWidgetRoute = null;
      }

      late final Widget? page;
      switch (consumed) {
        case LaunchAction.openVoiceTransaction:
          page = const VoiceAddTransactionPage();
        case LaunchAction.openCameraTransaction:
          page = const ReceiptOcrPage();
        case LaunchAction.openHistoryTransaction:
          page = null;
          context.read<NotificationListenerService>().clearPendingReviews();
          navigator.popUntil((route) => route.isFirst);
          navigator.pushNamed('/transactions');
        case LaunchAction.openHistoryTransfer:
          page = null;
          context.read<NotificationListenerService>().clearPendingReviews();
          navigator.popUntil((route) => route.isFirst);
          navigator.pushNamed('/accounts');
      }

      if (page != null) {
        final route = MaterialPageRoute<bool>(
          builder: (_) => page!,
          fullscreenDialog: true,
        );
        _activeWidgetRoute = route;

        // Don't await — release _handling immediately so new actions
        // from the widget can be processed right away.
        navigator.push(route).then((_) {
          _activeWidgetRoute = null;
        });
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
