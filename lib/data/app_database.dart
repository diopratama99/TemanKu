import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  bool _initialized = false;

  SupabaseClient get client => Supabase.instance.client;

  /// Scoped query builder bound to our own Postgres schema (`temanku`).
  ///
  /// All TemanKu app tables live in the dedicated `temanku` schema on
  /// the self-hosted Supabase instance — `public` stays reserved for
  /// cross-app/stock objects (and for other apps like IngatanKu /
  /// BensinKu that share the same Postgres). Using [client.schema] here
  /// means every `.from(...)` and `.rpc(...)` call below resolves to
  /// `temanku.<name>` without sprinkling the schema string all over the
  /// codebase.
  ///
  /// NOTE: Keep using [client] directly for `.auth`, `.functions`, and
  /// `.storage` — those are schema-independent.
  SupabaseQuerySchema get db => client.schema('temanku');
  String? get currentUserId => client.auth.currentUser?.id;

  Future<void> init() async {
    if (_initialized) return;

    final jsonStr = await rootBundle.loadString('supabase.json');
    final config = jsonDecode(jsonStr) as Map<String, dynamic>;

    await Supabase.initialize(
      url: config['SUPABASE_URL'] as String,
      anonKey: config['SUPABASE_ANON_KEY'] as String,
    );

    _initialized = true;
  }

  // ─── HELPERS ───────────────────────────────────────────────────────────

  String _lastDayOfMonth(String ym) {
    final parts = ym.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    // Day 0 of next month = last day of current month
    final last = DateTime(year, month + 1, 0);
    return last.day.toString().padLeft(2, '0');
  }

  // ─── CATEGORIES ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategories(String type) async {
    return await db
        .from('categories')
        .select()
        .eq('type', type)
        .order('name');
  }

  Future<Map<String, dynamic>> insertCategory(Map<String, dynamic> data) async {
    return await db.from('categories').insert(data).select().single();
  }

  Future<void> updateCategory(int id, Map<String, dynamic> data) async {
    await db.from('categories').update(data).eq('id', id);
  }

  Future<void> deleteCategory(int id) async {
    await db.from('categories').delete().eq('id', id);
  }

  // ─── TRANSACTIONS ──────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getTransactions({
    String? startDate,
    String? endDate,
    String? type,
    int? limit,
  }) async {
    var query = db
        .from('transactions')
        .select('*, categories(name, emoji)');

    if (type != null) query = query.eq('type', type);
    if (startDate != null) query = query.gte('date', startDate);
    if (endDate != null) query = query.lte('date', endDate);

    var ordered = query.order('date', ascending: false).order('id', ascending: false);

    final rows = limit != null ? await ordered.limit(limit) : await ordered;
    return rows.map<Map<String, dynamic>>((r) {
      final cat = r['categories'] as Map<String, dynamic>?;
      return {
        ...r,
        'category': cat?['name'] ?? '-',
        'category_emoji': cat?['emoji'],
        'keterangan': r['source_or_payee'],
        'payment_method': r['account'],
      };
    }).toList();
  }

  Future<Map<String, dynamic>> insertTransaction(
    Map<String, dynamic> data,
  ) async {
    return await db.from('transactions').insert(data).select().single();
  }

  Future<void> updateTransaction(int id, Map<String, dynamic> data) async {
    await db.from('transactions').update(data).eq('id', id);
  }

  Future<void> deleteTransaction(int id) async {
    await db.from('transactions').delete().eq('id', id);
  }

  // ─── BUDGETS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getBudgetsWithSpent(String month) async {
    final budgets = await db
        .from('budgets')
        .select('*, categories(name, emoji)')
        .eq('month', month);

    final lastDay = _lastDayOfMonth(month);
    final trx = await db
        .from('transactions')
        .select('category_id, amount')
        .eq('type', 'expense')
        .gte('date', '$month-01')
        .lte('date', '$month-$lastDay');

    final spentMap = <int, double>{};
    for (final t in trx) {
      final catId = t['category_id'] as int;
      spentMap[catId] = (spentMap[catId] ?? 0) + (t['amount'] as num).toDouble();
    }

    final result = budgets.map<Map<String, dynamic>>((b) {
      final cat = b['categories'] as Map<String, dynamic>?;
      final catId = b['category_id'] as int;
      return {
        'id': b['id'],
        'category': cat?['name'] ?? '-',
        'emoji': cat?['emoji'],
        'category_id': catId,
        'amount': b['amount'],
        'limit_amount': b['amount'],
        'spent': spentMap[catId] ?? 0.0,
      };
    }).toList();
    result.sort((a, b) => (a['category'] as String).compareTo(b['category'] as String));
    return result;
  }

  Future<Map<String, dynamic>> insertBudget(Map<String, dynamic> data) async {
    return await db.from('budgets').insert(data).select().single();
  }

  Future<void> updateBudget(int id, Map<String, dynamic> data) async {
    await db.from('budgets').update(data).eq('id', id);
  }

  Future<void> deleteBudget(int id) async {
    await db.from('budgets').delete().eq('id', id);
  }

  // ─── SAVINGS ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSavingsGoals() async {
    final goals = await db
        .from('savings_goals')
        .select('*, savings_allocations(amount)')
        .order('created_at', ascending: false);

    return goals.map<Map<String, dynamic>>((g) {
      final allocations = g['savings_allocations'] as List? ?? [];
      final allocated = allocations.fold<double>(
        0.0,
        (sum, a) => sum + ((a as Map)['amount'] as num).toDouble(),
      );
      return {
        'id': g['id'],
        'name': g['name'],
        'target_amount': g['target_amount'],
        'archived_at': g['archived_at'],
        'created_at': g['created_at'],
        'allocated': allocated,
      };
    }).toList();
  }

  Future<Map<String, dynamic>> insertSavingsGoal(
    Map<String, dynamic> data,
  ) async {
    return await db.from('savings_goals').insert(data).select().single();
  }

  Future<void> updateSavingsGoal(int id, Map<String, dynamic> data) async {
    await db.from('savings_goals').update(data).eq('id', id);
  }

  Future<void> deleteSavingsGoal(int id) async {
    await db.from('savings_allocations').delete().eq('goal_id', id);
    await db.from('savings_goals').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> insertSavingsAllocation(
    Map<String, dynamic> data,
  ) async {
    return await db
        .from('savings_allocations')
        .insert(data)
        .select()
        .single();
  }

  // ─── ACCOUNT TRANSFERS ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAccountTransfers() async {
    return await db
        .from('account_transfers')
        .select()
        .order('date', ascending: false)
        .order('id', ascending: false);
  }

  Future<void> deleteAccountTransfer(int id) async {
    await db.from('account_transfers').delete().eq('id', id);
  }

  Future<void> insertAccountTransferWithFee({
    required String dateIso,
    required String fromAccount,
    required String toAccount,
    required double amount,
    String? note,
    double adminFee = 0,
  }) async {
    await db.rpc('insert_transfer_with_fee', params: {
      'p_date': dateIso,
      'p_from_account': fromAccount,
      'p_to_account': toAccount,
      'p_amount': amount,
      'p_note': note,
      'p_admin_fee': adminFee,
    });
  }

  // ─── ACCOUNT BALANCES ──────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> accountBalancesAllTime() async {
    final base = {'Transfer': 0.0, 'Tunai': 0.0, 'E-Wallet': 0.0};

    final trxRows = await db
        .from('transactions')
        .select('account, type, amount')
        .inFilter('account', ['Transfer', 'Tunai', 'E-Wallet']);

    for (final r in trxRows) {
      final acc = r['account'] as String?;
      final type = r['type'] as String?;
      final amount = (r['amount'] as num).toDouble();
      if (acc != null && base.containsKey(acc)) {
        base[acc] = base[acc]! + (type == 'income' ? amount : -amount);
      }
    }

    final transfers = await db
        .from('account_transfers')
        .select('from_account, to_account, amount');

    for (final r in transfers) {
      final from = r['from_account'] as String;
      final to = r['to_account'] as String;
      final amt = (r['amount'] as num).toDouble();
      if (base.containsKey(from)) base[from] = base[from]! - amt;
      if (base.containsKey(to)) base[to] = base[to]! + amt;
    }

    String label(String a) =>
        a == 'Transfer' ? 'Rekening' : (a == 'E-Wallet' ? 'E-Wallet' : 'Tunai');

    return base.entries
        .map((e) => {'acc': e.key, 'label': label(e.key), 'saldo': e.value})
        .toList();
  }

  Future<List<Map<String, dynamic>>> accountBalancesByMonth(String ym) async {
    final base = {'Transfer': 0.0, 'Tunai': 0.0, 'E-Wallet': 0.0};

    final trxRows = await db
        .from('transactions')
        .select('account, type, amount')
        .inFilter('account', ['Transfer', 'Tunai', 'E-Wallet'])
        .gte('date', '$ym-01')
        .lte('date', '$ym-${_lastDayOfMonth(ym)}');

    for (final r in trxRows) {
      final acc = r['account'] as String?;
      final type = r['type'] as String?;
      final amount = (r['amount'] as num).toDouble();
      if (acc != null && base.containsKey(acc)) {
        base[acc] = base[acc]! + (type == 'income' ? amount : -amount);
      }
    }

    final transfers = await db
        .from('account_transfers')
        .select('from_account, to_account, amount')
        .gte('date', '$ym-01')
        .lte('date', '$ym-${_lastDayOfMonth(ym)}');

    for (final r in transfers) {
      final from = r['from_account'] as String;
      final to = r['to_account'] as String;
      final amt = (r['amount'] as num).toDouble();
      if (base.containsKey(from)) base[from] = base[from]! - amt;
      if (base.containsKey(to)) base[to] = base[to]! + amt;
    }

    String label(String a) =>
        a == 'Transfer' ? 'Rekening' : (a == 'E-Wallet' ? 'E-Wallet' : 'Tunai');

    return base.entries
        .map((e) => {'acc': e.key, 'label': label(e.key), 'saldo': e.value})
        .toList();
  }

  // ─── DASHBOARD ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> dashboardData(
    String startIso,
    String endIso,
  ) async {
    // Two parallel queries:
    //   1. Current month's transactions (full columns for aggregations).
    //   2. All prior-month transactions (type+amount only) to compute the
    //      carry-over balance so "Sisa Saldo" on the dashboard reflects
    //      the user's cumulative wallet, not just this month's net. Fixes
    //      the bug where a user starting a new month sees their balance
    //      reset to near-zero and panics about missing money.
    final currentMonthFuture = db
        .from('transactions')
        .select(
          'type, amount, category_id, source_or_payee, date, id, account, notes',
        )
        .gte('date', startIso)
        .lte('date', endIso);

    final priorMonthsFuture = db
        .from('transactions')
        .select('type, amount')
        .lt('date', startIso);

    final results = await Future.wait([
      currentMonthFuture,
      priorMonthsFuture,
    ]);
    final allTrx = results[0];
    final priorTrx = results[1];

    // Carry-over (net of everything strictly before `startIso`).
    double priorIncome = 0, priorExpense = 0;
    for (final t in priorTrx) {
      final amount = (t['amount'] as num).toDouble();
      if (t['type'] == 'income') {
        priorIncome += amount;
      } else {
        priorExpense += amount;
      }
    }
    final carryover = priorIncome - priorExpense;

    double income = 0, expense = 0;
    final spendByCat = <int, double>{};
    final payeeMap = <String, _PayeeAgg>{};

    for (final t in allTrx) {
      final type = t['type'] as String;
      final amount = (t['amount'] as num).toDouble();
      if (type == 'income') {
        income += amount;
      } else {
        expense += amount;
        final catId = t['category_id'] as int;
        spendByCat[catId] = (spendByCat[catId] ?? 0) + amount;
        final payee = (t['source_or_payee'] as String?) ?? '(Tidak diisi)';
        final agg = payeeMap.putIfAbsent(payee, () => _PayeeAgg());
        agg.total += amount;
        agg.count++;
      }
    }

    // Resolve category names for spend
    final catIds = spendByCat.keys.toList();
    List<Map<String, dynamic>> spendList = [];
    if (catIds.isNotEmpty) {
      final cats = await db
          .from('categories')
          .select('id, name, emoji')
          .inFilter('id', catIds);
      final catMap = {for (final c in cats) c['id'] as int: c};
      spendList = spendByCat.entries.map((e) {
        final c = catMap[e.key];
        return {
          'category': c?['name'] ?? '-',
          'emoji': c?['emoji'],
          'category_id': e.key,
          'total': e.value,
        };
      }).toList()
        ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double));
    }

    // Top payee
    Map<String, dynamic>? topPayee;
    if (payeeMap.isNotEmpty) {
      final sorted = payeeMap.entries.toList()
        ..sort((a, b) => b.value.total.compareTo(a.value.total));
      final top = sorted.first;
      topPayee = {'payee': top.key, 'total': top.value.total, 'cnt': top.value.count};
    }

    // Budgets with spent
    final month = startIso.substring(0, 7);
    final budgets = await getBudgetsWithSpent(month);

    // Latest transactions
    final latest = await getTransactions(
      startDate: startIso,
      endDate: endIso,
      limit: 10,
    );

    // Active goals
    final allGoals = await getSavingsGoals();
    final activeGoals = allGoals
        .where((g) => g['archived_at'] == null)
        .take(6)
        .toList();

    return {
      'income': income,
      'expense': expense,
      // `net` = current month's delta only. Kept for the statistics page
      // which shows "Selisih Bulan Ini".
      'net': income - expense,
      // `carryover` = net of all transactions strictly before the
      // selected month. Exposed so the UI can optionally show "saldo
      // bulan lalu" as a subtitle.
      'carryover': carryover,
      // `balance` = cumulative wallet balance (carryover + current
      // month delta). This is the value the dashboard should display as
      // "Sisa Saldo" so users don't see their money "reset" each month.
      'balance': carryover + income - expense,
      'spend_by_cat': spendList,
      'top_payee': topPayee,
      'budgets': budgets,
      'latest': latest,
      'active_goals': activeGoals,
    };
  }

  // ─── PROFILE ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUserId;
    if (uid == null) return null;
    try {
      final row = await db
          .from('profiles')
          .select()
          .eq('id', uid)
          .single();
      return {
        ...row,
        'email': client.auth.currentUser?.email,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid == null) return;
    await db.from('profiles').upsert({'id': uid, ...data});
  }

  // ─── DEBTS ───────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getDebts({String? status}) async {
    var query = db.from('debts').select('*, debt_payments(amount)');
    if (status != null) {
      query = query.eq('status', status);
    }
    final List<dynamic> data = await query.order('created_at', ascending: false);
    
    return data.map<Map<String, dynamic>>((row) {
      final r = Map<String, dynamic>.from(row);
      final payments = r['debt_payments'] as List<dynamic>? ?? [];
      double totalPaid = 0;
      for (final p in payments) {
        totalPaid += (p['amount'] as num?)?.toDouble() ?? 0;
      }
      r['paid_amount'] = totalPaid;
      return r;
    }).toList();
  }

  Future<Map<String, dynamic>> insertDebt(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid != null) data['user_id'] = uid;
    return await db.from('debts').insert(data).select().single();
  }

  Future<void> updateDebt(int id, Map<String, dynamic> data) async {
    await db.from('debts').update(data).eq('id', id);
  }

  Future<void> deleteDebt(int id) async {
    await db.from('debts').delete().eq('id', id);
  }

  Future<void> insertDebtPayment(Map<String, dynamic> data) async {
    final uid = currentUserId;
    if (uid != null) data['user_id'] = uid;
    await db.from('debt_payments').insert(data);
  }

  // ─── EXPORT HELPER ─────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> exportTransactions() async {
    final rows = await db
        .from('transactions')
        .select('date, type, amount, source_or_payee, account, notes, categories(name)')
        .order('date', ascending: false);

    return rows.map<Map<String, dynamic>>((r) {
      final cat = r['categories'] as Map<String, dynamic>?;
      return {
        'date': r['date'],
        'type': r['type'],
        'category': cat?['name'] ?? '-',
        'amount': r['amount'],
        'source_or_payee': r['source_or_payee'],
        'account': r['account'],
        'notes': r['notes'],
      };
    }).toList();
  }
}

class _PayeeAgg {
  double total = 0;
  int count = 0;
}

