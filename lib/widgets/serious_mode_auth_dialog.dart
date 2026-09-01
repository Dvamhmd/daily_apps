import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/model_serious_mode.dart';
import '../utils/serious_mode_service.dart';
import 'avatar_crop_preview_dialog.dart';
import 'custom_toast.dart';

class SeriousModeAuthDialog extends StatefulWidget {
  final bool isEditingProfile;

  static const List<Map<String, dynamic>> presetAvatars = [
    {'emoji': '🦁', 'name': 'Singa Juara', 'color': 0xFFF59E0B},
    {'emoji': '⚡', 'name': 'Flash Fokus', 'color': 0xFF3B82F6},
    {'emoji': '👑', 'name': 'Sultan Task', 'color': 0xFFEAB308},
    {'emoji': '🥷', 'name': 'Ninja Disiplin', 'color': 0xFF6366F1},
    {'emoji': '🐉', 'name': 'Naga Produktif', 'color': 0xFF10B981},
    {'emoji': '🚀', 'name': 'Rocket Man', 'color': 0xFFEC4899},
    {'emoji': '🥊', 'name': 'Fighter', 'color': 0xFFEF4444},
    {'emoji': '🧠', 'name': 'Mastermind', 'color': 0xFF8B5CF6},
  ];

  const SeriousModeAuthDialog({
    super.key,
    this.isEditingProfile = false,
  });

  static Future<SeriousUser?> show(BuildContext context, {bool isEditingProfile = false}) {
    return showDialog<SeriousUser>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => SeriousModeAuthDialog(isEditingProfile: isEditingProfile),
    );
  }

  static Future<SeriousUser?> showEditProfile(BuildContext context) {
    return showDialog<SeriousUser>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const SeriousModeAuthDialog(isEditingProfile: true),
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
  bool _isPickingImage = false;
  SeriousUser? _currentUser;

  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _displayNameController = TextEditingController();
  int _selectedAvatarIndex = 0;
  String? _customAvatarBase64;
  Uint8List? _lastPickedRawBytes;

  static List<Map<String, dynamic>> get _presetAvatars => SeriousModeAuthDialog.presetAvatars;

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
        if (widget.isEditingProfile && cur != null) {
          _displayNameController.text = cur.displayName;
          _usernameController.text = cur.username;
          _passwordController.text = cur.password;
          _selectedAvatarIndex = cur.avatarIndex;
          _customAvatarBase64 = cur.avatarBase64;
        } else if (cur != null) {
          _isLoginMode = true;
        }
      });
    }
  }

  /// Pilih foto profil kustom langsung dari galeri HP Android / perangkat & buka tool crop interaktif
  Future<void> _pickCustomAvatar() async {
    setState(() {
      _isPickingImage = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'bmp'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? rawBytes = file.bytes;

        if (rawBytes == null && file.path != null && !kIsWeb) {
          rawBytes = await File(file.path!).readAsBytes();
        }

        if (rawBytes != null && rawBytes.isNotEmpty) {
          _lastPickedRawBytes = rawBytes;
          if (!mounted) return;
          
          final croppedBase64 = await AvatarCropPreviewDialog.show(
            context,
            imageBytes: rawBytes,
            displayName: _displayNameController.text.trim().isNotEmpty
                ? _displayNameController.text.trim()
                : (_usernameController.text.trim().isNotEmpty
                    ? _usernameController.text.trim()
                    : 'Pemain'),
          );

          if (croppedBase64 != null && croppedBase64.isNotEmpty && mounted) {
            setState(() {
              _customAvatarBase64 = croppedBase64;
            });
            CustomToast.showSuccess(
              context,
              title: 'Foto Terpasang!',
              subtitle: 'Foto profil avatar kustom Anda siap digunakan & tersinkron!',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking avatar image: $e');
      if (mounted) {
        CustomToast.showError(
          context,
          title: 'Gagal Memilih Foto',
          subtitle: '$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  /// Sesuaikan ulang crop foto yang sudah pernah dipilih
  Future<void> _reAdjustCurrentCrop() async {
    if (_lastPickedRawBytes == null) {
      _pickCustomAvatar();
      return;
    }
    final croppedBase64 = await AvatarCropPreviewDialog.show(
      context,
      imageBytes: _lastPickedRawBytes!,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : (_usernameController.text.trim().isNotEmpty
              ? _usernameController.text.trim()
              : 'Pemain'),
    );

    if (croppedBase64 != null && croppedBase64.isNotEmpty && mounted) {
      setState(() {
        _customAvatarBase64 = croppedBase64;
      });
      CustomToast.showSuccess(
        context,
        title: 'Posisi Foto Diperbarui!',
        subtitle: 'Hasil penyesuaian foto berhasil disimpan.',
      );
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

    Widget avatarWidget;
    if (_currentUser!.avatarBase64 != null && _currentUser!.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_currentUser!.avatarBase64!);
        avatarWidget = ClipOval(
          child: Image.memory(
            bytes,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {
        avatarWidget = Text(
          avatarData['emoji'] as String,
          style: const TextStyle(fontSize: 20),
        );
      }
    } else {
      avatarWidget = Text(
        avatarData['emoji'] as String,
        style: const TextStyle(fontSize: 20),
      );
    }

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
            child: avatarWidget,
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

    if (!widget.isEditingProfile && password.isEmpty) {
      CustomToast.showError(context, title: 'Password wajib diisi!');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingMessage = widget.isEditingProfile
          ? 'Menyimpan Profil'
          : (_isLoginMode ? 'Masuk ke Akun' : 'Mendaftarkan Akun');
    });

    HapticFeedback.mediumImpact();

    if (widget.isEditingProfile) {
      final res = await SeriousModeService.updateUserProfile(
        newDisplayName: displayName.isNotEmpty ? displayName : username,
        newUsername: username,
        newPassword: password.isNotEmpty ? password : null,
        avatarBase64: _customAvatarBase64,
        avatarIndex: _selectedAvatarIndex,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingMessage = '';
        });
        if (res['success'] == true) {
          final user = res['user'] as SeriousUser;
          CustomToast.showSuccess(
            context,
            title: 'Profil Diperbarui!',
            subtitle: 'Profil "${user.displayName}" (@${user.username}) berhasil disimpan dan disinkronkan! 🔥',
          );
          Navigator.of(context).pop(user);
        } else {
          CustomToast.showError(
            context,
            title: 'Gagal Memperbarui Profil',
            subtitle: res['message']?.toString() ?? 'Gagal menyimpan perubahan profil',
          );
        }
      }
      return;
    }

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
        avatarBase64: _customAvatarBase64,
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

  Widget _buildAvatarSelector() {
    final avatarData = _presetAvatars[_selectedAvatarIndex.clamp(0, _presetAvatars.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'FOTO / AVATAR PEMAIN',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            if (_customAvatarBase64 != null)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _customAvatarBase64 = null;
                  });
                },
                child: const Text(
                  'Hapus Foto (Gunakan Emoji)',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Main Avatar Card Preview & Upload Button
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _customAvatarBase64 != null
                  ? accentGold.withValues(alpha: 0.6)
                  : Colors.white12,
              width: _customAvatarBase64 != null ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar Circle
              GestureDetector(
                onTap: _isPickingImage
                    ? null
                    : (_customAvatarBase64 != null
                        ? _reAdjustCurrentCrop
                        : _pickCustomAvatar),
                child: Stack(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _customAvatarBase64 != null
                            ? Colors.black26
                            : Color(avatarData['color'] as int).withValues(alpha: 0.25),
                        border: Border.all(
                          color: _customAvatarBase64 != null
                              ? accentGold
                              : Color(avatarData['color'] as int),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: _customAvatarBase64 != null
                          ? ClipOval(
                              child: Image.memory(
                                base64Decode(_customAvatarBase64!),
                                width: 58,
                                height: 58,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Text(
                              avatarData['emoji'] as String,
                              style: const TextStyle(fontSize: 28),
                            ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          color: _customAvatarBase64 != null
                              ? const Color(0xFF10B981)
                              : accentGold,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _customAvatarBase64 != null
                              ? Icons.crop_rounded
                              : Icons.add_a_photo_rounded,
                          color: Colors.black,
                          size: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customAvatarBase64 != null
                          ? 'Foto Galeri Terpasang'
                          : avatarData['name'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _customAvatarBase64 != null
                          ? 'Ketuk untuk zoom & atur posisi crop'
                          : 'Pilih foto galeri atau karakter emoji',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_customAvatarBase64 != null)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          InkWell(
                            onTap: _isPickingImage ? null : _reAdjustCurrentCrop,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: accentGold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: accentGold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.crop_rounded,
                                    color: accentGold,
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Sesuaikan Crop',
                                    style: TextStyle(
                                      color: accentGold,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: _isPickingImage ? null : _pickCustomAvatar,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white24,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.photo_library_rounded,
                                    color: Colors.white70,
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'Ganti Foto',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      InkWell(
                        onTap: _isPickingImage ? null : _pickCustomAvatar,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accentGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accentGold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isPickingImage)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: accentGold,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.photo_library_rounded,
                                  color: accentGold,
                                  size: 15,
                                ),
                              const SizedBox(width: 6),
                              const Text(
                                'Ambil Foto dari Galeri',
                                style: TextStyle(
                                  color: accentGold,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
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

        const SizedBox(height: 12),

        // Emoji presets list
        const Text(
          'Atau pilih preset emoji:',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.white54,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _presetAvatars.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, idx) {
              final item = _presetAvatars[idx];
              final isSelected = _selectedAvatarIndex == idx && _customAvatarBase64 == null;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedAvatarIndex = idx;
                    _customAvatarBase64 = null; // Clear custom photo if emoji is picked
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color(item['color'] as int).withValues(alpha: 0.25)
                        : cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Color(item['color'] as int)
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    item['emoji'] as String,
                    style: TextStyle(
                      fontSize: isSelected ? 22 : 18,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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
                              Text(
                                widget.isEditingProfile
                                    ? 'EDIT PROFIL'
                                    : 'MODE SERIUS',
                                style: const TextStyle(
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
                                child: Text(
                                  widget.isEditingProfile ? 'PLAYER' : 'GAMES',
                                  style: const TextStyle(
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
                            widget.isEditingProfile
                                ? 'Ubah nama tampilan, username, atau foto avatar'
                                : (_isLoginMode
                                    ? 'Masuk ke akun profil pemain'
                                    : 'Buat akun terintegrasi Spreadsheet'),
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
                    if (_currentUser != null && !widget.isEditingProfile)
                      _buildActiveAccountBanner(),

                    // Mode Switcher Tab (Hanya saat bukan mode edit profil)
                    if (!widget.isEditingProfile) ...[
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
                    ],

                    // Avatar Picker & Nama Lengkap (Saat daftar baru ATAU saat edit profil)
                    if (!_isLoginMode || widget.isEditingProfile) ...[
                      _buildAvatarSelector(),
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
                    Text(
                      widget.isEditingProfile
                          ? 'PASSWORD BARU (OPSIONAL)'
                          : 'PASSWORD',
                      style: const TextStyle(
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
                        hintText: widget.isEditingProfile
                            ? 'Kosongkan jika tidak ingin mengubah'
                            : 'Minimal 4 karakter',
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
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded,
                              color: Color(0xFF818CF8), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.isEditingProfile
                                  ? 'Perubahan profil & avatar akan otomatis disinkronkan ke Spreadsheet & Leaderboard.'
                                  : 'Di Mode Serius: Tugas yang sudah dibuat TIDAK BISA DIHAPUS. Poin & Ranking tersinkron.',
                              style: const TextStyle(
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
                                  Icon(widget.isEditingProfile
                                      ? Icons.save_rounded
                                      : (_isLoginMode
                                          ? Icons.login_rounded
                                          : Icons.play_arrow_rounded)),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.isEditingProfile
                                        ? 'Simpan Perubahan Profil 🔥'
                                        : (_isLoginMode
                                            ? 'Masuk Mode Serius'
                                            : 'Mulai Mode Serius 🔥'),
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
