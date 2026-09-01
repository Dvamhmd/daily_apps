import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/model_serious_mode.dart';
import '../utils/serious_mode_service.dart';

class SeriousLeaderboardModal extends StatefulWidget {
  const SeriousLeaderboardModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const SeriousLeaderboardModal(),
    );
  }

  @override
  State<SeriousLeaderboardModal> createState() =>
      _SeriousLeaderboardModalState();
}

class _SeriousLeaderboardModalState extends State<SeriousLeaderboardModal> {
  static const Color darkBg = Color(0xFF0F172A);
  static const Color cardBg = Color(0xFF1E293B);
  static const Color accentGold = Color(0xFFF59E0B);

  List<SeriousUser> _users = [];
  SeriousUser? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final curUser = await SeriousModeService.getCurrentUser();
    final list = await SeriousModeService.getLeaderboard();
    if (mounted) {
      setState(() {
        _currentUser = curUser;
        _users = list;
        _isLoading = false;
      });
    }
  }

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

  Widget _buildAvatar(SeriousUser user, {double size = 48}) {
    if (user.avatarBase64 != null && user.avatarBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(user.avatarBase64!);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        );
      } catch (_) {}
    }

    final avatarIdx = user.avatarIndex.clamp(0, _presetAvatars.length - 1);
    final avatarData = _presetAvatars[avatarIdx];
    return Container(
      width: size,
      height: size,
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
        style: TextStyle(fontSize: size * 0.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top3 = _users.take(3).toList();
    final remaining = _users.skip(3).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag Handle & Header
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: accentGold, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEADERBOARD TOP 3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                      Text(
                        'Peringkat pemain paling produktif terintegrasi',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Segarkan Data',
                  icon: const Icon(Icons.refresh_rounded, color: accentGold),
                  onPressed: () {
                    setState(() => _isLoading = true);
                    _loadLeaderboard();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white60),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: accentGold),
                  )
                : (_users.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            // PODIUM TOP 3
                            if (top3.isNotEmpty)
                              _buildTop3Podium(top3),

                            const SizedBox(height: 24),

                            // Section List Peringkat Lainnya
                            if (remaining.isNotEmpty) ...[
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'PESERTA LAINNYA (${remaining.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF94A3B8),
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...remaining.asMap().entries.map((entry) {
                                final rank = entry.key + 4;
                                final user = entry.value;
                                final isMe = _currentUser?.id == user.id;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isMe
                                        ? accentGold.withValues(alpha: 0.1)
                                        : cardBg,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isMe ? accentGold : Colors.white10,
                                      width: isMe ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        '#$rank',
                                        style: TextStyle(
                                          color: isMe
                                              ? accentGold
                                              : const Color(0xFF94A3B8),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _buildAvatar(user, size: 36),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    user.displayName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 13,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMe)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: accentGold,
                                                      borderRadius:
                                                          BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'KAMU',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.black,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            Text(
                                              '${user.totalTasksCompleted} Task Selesai',
                                              style: const TextStyle(
                                                color: Colors.white54,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${user.totalPoints} PTS',
                                            style: TextStyle(
                                              color: isMe
                                                  ? accentGold
                                                  : Colors.white,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  Widget _buildTop3Podium(List<SeriousUser> top3) {
    SeriousUser? first = top3.isNotEmpty ? top3[0] : null;
    SeriousUser? second = top3.length > 1 ? top3[1] : null;
    SeriousUser? third = top3.length > 2 ? top3[2] : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Juara 2 (Perak)
        if (second != null)
          Expanded(
            child: _buildPodiumColumn(
              user: second,
              rank: 2,
              height: 120,
              badgeColor: const Color(0xFF94A3B8),
              crownIcon: '🥈',
              isCurrent: _currentUser?.id == second.id,
            ),
          )
        else
          const Spacer(),

        const SizedBox(width: 10),

        // Juara 1 (Emas - Tertinggi di Tengah)
        if (first != null)
          Expanded(
            child: _buildPodiumColumn(
              user: first,
              rank: 1,
              height: 155,
              badgeColor: accentGold,
              crownIcon: '👑',
              isCurrent: _currentUser?.id == first.id,
            ),
          )
        else
          const Spacer(),

        const SizedBox(width: 10),

        // Juara 3 (Perunggu)
        if (third != null)
          Expanded(
            child: _buildPodiumColumn(
              user: third,
              rank: 3,
              height: 95,
              badgeColor: const Color(0xFFD97706),
              crownIcon: '🥉',
              isCurrent: _currentUser?.id == third.id,
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  Widget _buildPodiumColumn({
    required SeriousUser user,
    required int rank,
    required double height,
    required Color badgeColor,
    required String crownIcon,
    required bool isCurrent,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crown & Avatar
        Text(crownIcon, style: const TextStyle(fontSize: 22)),
        const SizedBox(height: 4),
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: badgeColor, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: badgeColor.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: _buildAvatar(user, size: rank == 1 ? 58 : 48),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '#$rank',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Nama & Poin
        Text(
          user.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? accentGold : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: rank == 1 ? 13 : 11.5,
          ),
        ),
        Text(
          '${user.totalPoints} PTS',
          style: TextStyle(
            color: badgeColor,
            fontWeight: FontWeight.w900,
            fontSize: rank == 1 ? 12.5 : 11,
          ),
        ),
        const SizedBox(height: 6),

        // Podium Block
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                badgeColor.withValues(alpha: 0.3),
                cardBg,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'RANK #$rank',
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${user.totalTasksCompleted} Selesai',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentGold.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accentGold.withValues(alpha: 0.3)),
              ),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: accentGold,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Belum Ada Pemain',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Belum ada data pemain di Spreadsheet atau lokal. Selesaikan tugas Anda di Mode Serius untuk mencetak poin dan menjadi pemain pertama di papan peringkat!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accentGold,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                'Segarkan / Cek Spreadsheet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadLeaderboard();
              },
            ),
          ],
        ),
      ),
    );
  }
}
