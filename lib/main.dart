import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'data/app_database.dart';
import 'services/auth_service.dart';
import 'state/auth_notifier.dart';
import 'state/theme_notifier.dart';
import 'pages/login_page.dart';
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
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await initializeDateFormatting('id_ID', null);
  await AppDatabase().init();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _db = AppDatabase();
  final _auth = AuthService();
  late Future<void> _init;

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
        ChangeNotifierProvider<AuthNotifier>(
          create: (_) => AuthNotifier(_auth),
        ),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, themeNotifier, _) {
          return MaterialApp(
            title: 'Temanku',
            theme: AppTheme.theme(),
            darkTheme: AppTheme.darkTheme(),
            themeMode: themeNotifier.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            debugShowCheckedModeBanner: false,
            routes: {
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
                if (auth.isLoggedIn) {
                  return const HomePage();
                }
                return const LoginPage();
              },
            ),
          );
        },
      ),
    );
  }
}

// AuthNotifier moved to state/auth_notifier.dart
