/// Localization strings for Indonesian (default)
///
/// Usage: AppLocalizations.of(context).welcome
///
/// Future: Extract to arb files for multi-language support
class AppLocalizations {
  static const Map<String, String> _id = {
    // General
    'app_name': 'TemanKu',
    'app_tagline': 'Kelola Keuangan Pribadi',
    'loading': 'Memuat...',
    'error': 'Terjadi kesalahan',
    'retry': 'Coba Lagi',
    'cancel': 'Batal',
    'save': 'Simpan',
    'delete': 'Hapus',
    'edit': 'Edit',
    'add': 'Tambah',
    'close': 'Tutup',

    // Navigation
    'nav_dashboard': 'Dashboard',
    'nav_transactions': 'Transaksi',
    'nav_add': 'Tambah',
    'nav_budget': 'Budget',
    'nav_profile': 'Profil',
    'nav_categories': 'Kategori',
    'nav_savings': 'Tabungan',
    'nav_accounts': 'Saldo Akun',
    'nav_import_export': 'Import/Export',

    // Auth
    'login': 'Masuk',
    'register': 'Daftar',
    'logout': 'Logout',
    'email': 'Email',
    'password': 'Password',
    'name': 'Nama Lengkap',
    'login_google': 'Masuk dengan Google',
    'login_success': 'Login berhasil!',
    'register_success': 'Registrasi berhasil!',
    'login_failed': 'Gagal login',
    'register_failed': 'Gagal daftar',

    // Dashboard
    'balance_remaining': 'Sisa Uang',
    'income': 'Pemasukan',
    'expense': 'Pengeluaran',
    'income_this_month': 'Pemasukan bulan ini',
    'expense_this_month': 'Pengeluaran bulan ini',
    'active_goals': 'Goals Aktif',
    'budget_this_month': 'Budget Bulan Ini',
    'account_details': 'Detail Uang',
    'expense_chart': 'Grafik Pengeluaran',
    'latest_transactions': '10 Transaksi Terakhir',
    'view_all': 'Lihat semua',
    'no_data': 'Belum ada data',
    'no_transactions': 'Belum ada transaksi',

    // Transactions
    'add_transaction': 'Tambah Transaksi',
    'transaction_type': 'Jenis',
    'transaction_income': 'Masuk',
    'transaction_expense': 'Keluar',
    'date': 'Tanggal',
    'category': 'Kategori',
    'amount': 'Jumlah',
    'payment_method': 'Metode Pembayaran',
    'payment_transfer': 'Rekening',
    'payment_cash': 'Tunai',
    'payment_ewallet': 'E-Wallet',
    'source_or_recipient': 'Sumber/Penerima',
    'notes': 'Catatan',
    'delete_transaction': 'Hapus Transaksi?',
    'delete_transaction_confirm': 'Tindakan ini tidak dapat dibatalkan.',

    // Categories
    'add_category': 'Tambah Kategori',
    'category_name': 'Nama Kategori',
    'no_categories': 'Belum Ada Kategori',
    'create_first_category':
        'Buat kategori pertama Anda untuk mulai melacak transaksi',

    // Form Validation
    'field_required': 'Field ini wajib diisi',
    'email_invalid': 'Email tidak valid',
    'password_min_length': 'Password minimal 8 karakter',
    'password_weak': 'Lemah',
    'password_medium': 'Sedang',
    'password_strong': 'Kuat',
    'amount_required': 'Jumlah tidak boleh kosong',

    // Empty States
    'empty_state_title': 'Belum Ada Data',
    'empty_state_description': 'Mulai tambahkan transaksi pertama Anda',

    // Error States
    'error_loading_data': 'Gagal Memuat Data',
    'error_network': 'Periksa koneksi internet Anda',
    'error_unknown': 'Terjadi kesalahan yang tidak diketahui',
  };

  /// Get localized string by key
  static String get(String key, [String? defaultValue]) {
    return _id[key] ?? defaultValue ?? key;
  }

  /// Check if key exists
  static bool has(String key) {
    return _id.containsKey(key);
  }

  // Convenience getters for common strings
  static String get appName => get('app_name');
  static String get loading => get('loading');
  static String get error => get('error');
  static String get save => get('save');
  static String get cancel => get('cancel');
  static String get delete => get('delete');
}
