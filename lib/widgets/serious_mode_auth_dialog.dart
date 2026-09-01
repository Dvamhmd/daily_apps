import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/model_serious_mode.dart';
import '../utils/serious_mode_service.dart';
import 'custom_toast.dart';

class SeriousModeAuthDialog extends StatefulWidget {
  const SeriousModeAuthDialog({super.key});

  static Future<SeriousUser?> show(BuildContext context) {
    return showDialog<SeriousUser>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const SeriousModeAuthDialog(),
    );
  }

  @override
  State<SeriousModeAuthDialog> createState() => _SeriousModeAuthDialogState();
}

class _SeriousModeAuthDialogState extends State<SeriousModeAuthDialog> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color accentGold = Color(0xFFF59E0B);
  static const Color accentFire = Color(0xFFEF4444);

  bool _isLoginMode = false;
  bool _obscurePassword = true;
  bool _isLoading = false;
  SeriousUser? _currentUser;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  int _selectedAvatarIndex = 0;

  static const List<Map<String, dynamic>> _presetAvatars = [
    {'emoji': '🦁', 'name': 'Singa Juara', 'color': 0xFFF59E0B},
    {'emoji': '⚡', 'name': 'Flash Fokus', 'color': 0xFF3B82F6},
    {'emoji': '👑', 'name': 'Sultan Task', 'color': 0xFFEAB308},
    {'emoji': '🥷', 'name': 'Ninja Disiplin', 'color': 0xFF6366F1},
    {'emoji': '🐉', 'name': 'Naga Produktif', 'color': 0xFF10B981},
    {'emoji': '🚀', 'name': 'Rocket Man', 'color': 0xFFEC4899},
    {'emoji': '🥊', 'name': 'Fighter', 'color': 0xFFEF4444},
    {'emoji': '🧠', 'name': 'Mastermind', 'color': 0xFF8B5CF6},
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final cur = await SeriousModeService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = cur;
        if (cur != null) {
          _isLoginMode = true;
        }
      });
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text(
              'Keluar dari Akun?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: Text(
          'Anda akan keluar dari akun "${_currentUser?.displayName ?? _currentUser?.username}". Mode Serius akan dinonaktifkan.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keluar Akun', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await SeriousModeService.logout();
      if (mounted) {
        CustomToast.showInfo(
          context,
          title: 'Berhasil Keluar',
          subtitle: 'Akun telah di-logout dari perangkat',
        );
        Navigator.of(context).pop(null);
      }
    }
  }

  Widget _buildActiveAccountBanner() {
    if (_currentUser == null) return const SizedBox.shrink();
    final avatarIdx = _currentUser!.avatarIndex.clamp(0, _presetAvatars.length - 1);
    final avatarData = _presetAvatars[avatarIdx];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentGold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Color(avatarData['color'] as int).withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(
                color: Color(avatarData['color'] as int),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              avatarData['emoji'] as String,
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AKUN AKTIF SAAT INI',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: accentGold,
                    letterSpacing: 0.8,
                  ),
                ),
                Text(
                  _currentUser!.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '@${_currentUser!.username} • ${_currentUser!.totalPoints} PTS',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Keluar Akun (Logout)',
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            onPressed: _handleLogout,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  String _loadingMessage = '';

  Future<void> _handleSubmit() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final displayName = _displayNameController.text.trim();

    if (username.isEmpty) {
      CustomToast.showError(context, title: 'Username wajib diisi!');
      return;
    }
    if (password.isEmpty) {
      CustomToast.showError(context, title: 'Password wajib diisi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = _isLoginMode
          ? 'Masuk ke Akun'
          : 'Mendaftarkan Akun';
    });

    HapticFeedback.mediumImpact();

    if (_isLoginMode) {
      final res = await SeriousModeService.loginUser(
        username: username,
        password: password,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
        if (res['success'] == true) {
          final user = res['user'] as SeriousUser;
          await SeriousModeService.fetchAndCacheUserTasksFromSpreadsheet(user);
          await SeriousModeService.setSeriousModeActive(true);
          if (mounted) {
            CustomToast.showSuccess(
              context,
              title: 'Selamat Datang!',
              subtitle: 'Selamat datang kembali, ${user.displayName}! 🔥',
            );
            Navigator.of(context).pop(user);
          }
        } else {
          CustomToast.showError(
            context,
            title: 'Gagal Login',
            subtitle: res['message']?.toString() ?? 'Username atau password salah',
          );
        }
      }
    } else {
      final res = await SeriousModeService.registerUser(
        username: username,
        password: password,
        displayName: displayName.isNotEmpty ? displayName : username,
        avatarIndex: _selectedAvatarIndex,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
        if (res['success'] == true) {
          final user = res['user'] as SeriousUser;
          await SeriousModeService.setSeriousModeActive(true);
          if (mounted) {
            CustomToast.showSuccess(
              context,
              title: 'Pendaftaran Berhasil',
              subtitle: 'Akun "${user.username}" berhasil terdaftar di Spreadsheet! 🔥',
            );
            Navigator.of(context).pop(user);
          }
        } else {
          CustomToast.showError(
            context,
            title: 'Gagal Mendaftar',
            subtitle: res['message']?.toString() ?? 'Gagal membuat akun',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: darkBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: accentGold.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentFire.withValues(alpha: 0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF831843), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Text('🎮', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'MODE SERIUS',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: accentGold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'GAMES',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _isLoginMode
                                ? 'Masuk ke akun profil pemain'
                                : 'Buat akun terintegrasi Spreadsheet',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Body Form
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentUser != null) _buildActiveAccountBanner(),

                    // Mode Switcher Tab
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLoginMode = false;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: !_isLoginMode
                                      ? accentGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Daftar Baru',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: !_isLoginMode
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _isLoginMode = true;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 9),
                                decoration: BoxDecoration(
                                  color: _isLoginMode
                                      ? accentGold
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Sudah Punya Akun',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                    color: _isLoginMode
                                        ? Colors.black
                                        : Colors.white70,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Avatar Picker (Hanya saat daftar baru)
                    if (!_isLoginMode) ...[
                      const Text(
                        'PILIH AVATAR PEMAIN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _presetAvatars.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (ctx, idx) {
                            final item = _presetAvatars[idx];
                            final isSelected = _selectedAvatarIndex == idx;
                            return GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _selectedAvatarIndex = idx;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Color(item['color'] as int)
                                          .withValues(alpha: 0.25)
                                      : cardBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? Color(item['color'] as int)
                                        : Colors.white12,
                                    width: isSelected ? 2.5 : 1,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  item['emoji'] as String,
                                  style: TextStyle(
                                    fontSize: isSelected ? 26 : 22,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Nama Lengkap
                      const Text(
                        'NAMA LENGKAP / PANGGILAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _displayNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Contoh: Arya Bima',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: cardBg,
                          prefixIcon: const Icon(Icons.badge_rounded,
                              color: Colors.white54, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: accentGold),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Username
                    const Text(
                      'USERNAME',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Contoh: aryabima_pro',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: cardBg,
                        prefixIcon: const Icon(Icons.person_rounded,
                            color: Colors.white54, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentGold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Password
                    const Text(
                      'PASSWORD',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Minimal 4 karakter',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: cardBg,
                        prefixIcon: const Icon(Icons.lock_rounded,
                            color: Colors.white54, size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: Colors.white54,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.white12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: accentGold),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Rules Badge Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B4B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.security_rounded,
                              color: Color(0xFF818CF8), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Di Mode Serius: Tugas yang sudah dibuat TIDAK BISA DIHAPUS. Poin & Ranking tersinkron.',
                              style: TextStyle(
                                color: Color(0xFFC7D2FE),
                                fontSize: 11,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentGold,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: accentGold,
                          disabledForegroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isLoading ? () {} : _handleSubmit,
                        child: _isLoading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.black,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      _loadingMessage.isNotEmpty
                                          ? _loadingMessage
                                          : 'Memproses...',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isLoginMode
                                      ? Icons.login_rounded
                                      : Icons.play_arrow_rounded),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isLoginMode
                                        ? 'Masuk Mode Serius'
                                        : 'Mulai Mode Serius 🔥',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
