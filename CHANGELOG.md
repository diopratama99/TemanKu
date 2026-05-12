# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.1] - 2025-10-28

### Added

- ☁️ **Google Drive Backup** - Backup and restore data to Google Drive
  - Auto-creates 'Temanku Backups' folder in Drive
  - Upload/download database backups
  - List and delete old backups
  - Works offline (only needs internet during backup)

### Improved

- 🔐 **Google Sign-In Configuration** - Updated OAuth credentials

  - Package name changed to `com.temanlabs.temanku`
  - Configured Android and Web OAuth Client IDs
  - Web Client ID configured for Drive API access
  - Enhanced error messages with setup instructions

- 🎨 **Login Page UI** - Better user experience

  - Changed "Email" field to "Username" with appropriate icon
  - Keyboard-responsive layout (logo hides when keyboard opens)
  - Working password visibility toggles for both login and register
  - Enhanced Google Sign-In button with actual Google logo
  - Consistent text field styling across all inputs
  - Username uses `Icons.person_outline`, Nama Lengkap uses `Icons.badge_outlined`

- 📤 **Import/Export Notifications** - Better user feedback
  - Fixed SnackBar layout overflow issues
  - Added "OK" button to dismiss notifications
  - Enhanced error messages with detailed instructions
  - Proper duration settings (3-5 seconds)

### Fixed

- 🔧 **Text Field Styling** - Consistent appearance
  - All text fields now use `AppTheme.textPrimary` color
  - Hint text uses grey shade 500 for better contrast
  - Password fields match regular field styling

### Changed

- 📦 **Package Name** - Updated to production package
  - Changed from `com.example.temanku_mobile` to `com.temanlabs.temanku`
  - Updated MainActivity.kt to new package structure

### Technical

- Google Drive API v3 integration with googleapis package
- serverClientId parameter for OAuth ID token retrieval
- Enhanced DriveBackupService with error handling
- SQLite database backup/restore functionality

## [1.5.0] - 2025-10-27

### Added

- 📊 **Trend Analysis Page** - Analisa tren keuangan dengan visualisasi grafik
  - Grafik line chart pengeluaran dengan prediksi tren
  - Support mode bulanan dan mingguan
  - Prediksi AI untuk periode berikutnya
  - Analisis korelasi antara pemasukan dan pengeluaran
  - Ringkasan statistik (rata-rata, max, min, standard deviation)
  - Insight otomatis berdasarkan pola pengeluaran

### Improved

- 📈 **Chart Visualization** - Optimasi tampilan grafik untuk dataset besar

  - Label X-axis dengan rotasi untuk readability lebih baik
  - Smart label interval (mingguan: setiap 4, bulanan: setiap 2)
  - Y-axis format dengan prefix "Rp" dan tanpa desimal
  - Custom tooltip dengan format Rupiah Indonesia
  - Font size yang disesuaikan untuk berbagai ukuran data
  - Garis prediksi tren yang tidak over-extend

- 🎯 **Budget Display** - Fix budget showing Rp 0 in dashboard

  - Corrected SQL query column alias from `amount` to `limit_amount`
  - Budget limits now display correctly in financial summary

- 📊 **Transaction Statistics** - Fix transaction count in statistics tab
  - Added dedicated `_loadTransactionCounts()` method with SQL COUNT query
  - Separated count logic from latest transactions query
  - Accurate income and expense transaction counts

### Fixed

- 🔧 **Login Page** - Added missing password label in login/register forms
- 🎨 **Dashboard UI** - Centered "Belum Ada Target" savings card with better width
- 💬 **Dialog Alignment** - Centered text and buttons in reset data confirmation dialogs
- 🔄 **Monthly Comparison** - Fixed compilation errors (imports, null safety, const issues)

### Changed

- 💱 **Currency Settings** - Removed currency selector from profile page
  - App now uses IDR (Rupiah Indonesia) only
  - Simplified codebase by removing multi-currency complexity
  - Cleaner profile page without currency dropdown

### Technical

- Linear regression for trend prediction
- Two-sample hypothesis testing for monthly comparison
- Correlation analysis between income and expense
- Optimized fl_chart configuration for large datasets
- Custom LineTouchTooltipData formatter
- Enhanced SQL queries for accurate data aggregation

## [1.0.1] - 2025-10-27

### Changed

- 🔧 Refactored codebase untuk naming convention yang lebih profesional
- 📝 Rename semua file page dari suffix `_modern` dan `_simple` ke nama standar
- 🧹 Cleanup file-file yang tidak terpakai (versi lama)
- 🗂️ Reorganisasi struktur project untuk maintainability lebih baik

### Removed

- ❌ Hapus file-file duplikat (login_page.dart versi lama, dll)
- ❌ Hapus page yang tidak terpakai (dashboard_page_v2.dart, ui_showcase_page.dart)
- ❌ Hapus widget yang tidak terpakai (app_scaffold.dart, balance_hero_card.dart)

### Technical

- Renamed: `login_page_modern.dart` → `login_page.dart`
- Renamed: `add_transaction_simple.dart` → `add_transaction_page.dart`
- Renamed: `profile_page_modern.dart` → `profile_page.dart`
- Renamed: `categories_page_modern.dart` → `categories_page.dart`
- Renamed: `transactions_page_modern.dart` → `transactions_page.dart`
- Renamed: `budgets_page_modern.dart` → `budgets_page.dart`
- Renamed: `savings_page_modern.dart` → `savings_page.dart`
- Renamed: `statistics_page_modern.dart` → `statistics_page.dart`
- Updated all imports dan references
- No breaking changes - app berjalan normal

## [1.0.0] - 2025-10-27

### Added

- 📱 Aplikasi mobile Temanku pertama kali dirilis
- 🎨 UI/UX modern dengan Material Design 3
- 🔐 Sistem autentikasi (Email/Password & Google Sign-In)
- 📊 Dashboard interaktif dengan grafik keuangan
- 💰 Manajemen transaksi (pemasukan & pengeluaran)
- 🏷️ Manajemen kategori transaksi
- 🏦 Manajemen akun (Cash, Bank, E-Wallet)
- 💳 Fitur transfer antar akun
- 🎯 Manajemen budget per kategori
- 💎 Fitur tabungan dengan target
- 📈 Riwayat transaksi lengkap dengan filter
- 📤 Import/Export data CSV
- 🎭 Profile card dengan design debit card style
- 🚀 Splash screen custom dengan logo Temanku
- 📱 Launcher icon custom
- ✨ Success dialog dengan animasi
- 🎨 Segmented control modern untuk login/register

### Features Details

#### Dashboard

- Ringkasan saldo total
- Grafik pie chart pengeluaran per kategori
- Grafik bar chart pengeluaran 7 hari terakhir
- Quick actions (Tambah Transaksi, Lihat Riwayat, dll)
- Recent transactions

#### Transaksi

- Form input simple dan intuitif
- Support pemasukan dan pengeluaran
- Auto-reset form setelah submit
- Animated success dialog

#### Login/Register

- Modern segmented control untuk tab switching
- Smooth animations (200ms background, 150ms text)
- Google Sign-In integration
- Form validation
- Eye-catching logo dan tagline

#### Profile

- Debit card style profile display
- Auto-uppercase nama
- Font Courier New untuk aesthetic
- Info user lengkap
- Logout functionality

### Technical

- Framework: Flutter 3.9.2
- State Management: Provider
- Database: SQLite (sqflite)
- Chart Library: fl_chart
- Authentication: Google Sign-In
- Custom Icons: flutter_launcher_icons
- Splash Screen: flutter_native_splash

### Fixed

- Navigation issues setelah add transaction
- Login navigation ke home page
- Form overflow pada landscape mode
- Spacing dan layout inconsistencies

---

## Upcoming Features

### [1.1.0] - Planned

- [ ] Dark mode support
- [ ] Notification & reminders
- [ ] Recurring transactions
- [ ] Multi-currency support
- [ ] Cloud backup & sync
- [ ] Expense insights & analytics
- [ ] Export to PDF
- [ ] Widget support
- [ ] Biometric authentication
- [ ] Tutorial & onboarding

---

## Developer Notes

### Build Info

- Minimum SDK: Android 21 (Lollipop)
- Target SDK: Android 34
- iOS Deployment Target: 12.0

### Dependencies

See `pubspec.yaml` for full list of dependencies and versions.
