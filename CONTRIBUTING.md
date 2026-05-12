# Contributing to Temanku Mobile

Terima kasih atas minat Anda untuk berkontribusi pada Temanku Mobile! 🎉

## 🤝 Cara Berkontribusi

### Melaporkan Bug

Jika Anda menemukan bug, silakan buat issue baru dengan informasi berikut:

- Deskripsi jelas tentang bug
- Langkah-langkah untuk mereproduksi
- Expected behavior vs actual behavior
- Screenshots (jika memungkinkan)
- Device & OS version
- Flutter version

### Mengusulkan Fitur Baru

Kami terbuka untuk saran fitur baru! Silakan:

1. Cek dulu apakah fitur sudah pernah diusulkan di Issues
2. Buat issue baru dengan label "enhancement"
3. Jelaskan kegunaan fitur tersebut
4. Berikan contoh use case jika memungkinkan

### Pull Request

1. Fork repository ini
2. Buat branch baru dari `main`:
   ```bash
   git checkout -b feature/nama-fitur
   ```
3. Commit changes Anda:
   ```bash
   git commit -m "feat: menambahkan fitur X"
   ```
4. Push ke branch Anda:
   ```bash
   git push origin feature/nama-fitur
   ```
5. Buat Pull Request ke branch `main`

## 📝 Code Style Guidelines

### Dart/Flutter

- Gunakan `flutter analyze` untuk cek code quality
- Format code dengan `flutter format .`
- Ikuti [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Gunakan meaningful variable names
- Tambahkan comments untuk logic yang kompleks

### Naming Conventions

- File names: `snake_case.dart`
- Class names: `PascalCase`
- Variables & functions: `camelCase`
- Constants: `UPPER_CASE`

### Commit Messages

Gunakan format [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` untuk fitur baru
- `fix:` untuk bug fixes
- `docs:` untuk dokumentasi
- `style:` untuk formatting
- `refactor:` untuk refactoring
- `test:` untuk testing
- `chore:` untuk maintenance

Contoh:

```
feat: tambah dark mode support
fix: perbaiki crash saat add transaction
docs: update README dengan installation guide
```

## 🧪 Testing

- Pastikan code Anda tidak break existing functionality
- Tambahkan tests untuk fitur baru jika memungkinkan
- Run `flutter test` sebelum submit PR

## 📁 Project Structure

Pahami struktur project sebelum berkontribusi:

```
lib/
├── main.dart           # Entry point
├── data/              # Database & models
├── pages/             # UI pages
├── services/          # Business logic
├── theme/             # Theme & styling
├── utils/             # Helper utilities
└── widgets/           # Reusable widgets
```

## ✅ Checklist Before Submit PR

- [ ] Code sudah diformat (`flutter format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Tested on Android/iOS (jika memungkinkan)
- [ ] Updated documentation jika perlu
- [ ] Commit messages follow conventions
- [ ] Screenshots ditambahkan untuk UI changes

## 💡 Questions?

Jika ada pertanyaan, feel free untuk:

- Buat issue dengan label "question"
- Contact: TemanLabs - [@diopratama99](https://github.com/diopratama99)

## 📜 Code of Conduct

Harap bersikap sopan dan respektful kepada semua kontributor.

---

**TemanLabs** - Made with ❤️ using Flutter

Happy coding! 🚀
