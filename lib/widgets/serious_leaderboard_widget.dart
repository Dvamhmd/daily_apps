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
    final top10 = _users.take(10).toList();
    final beyondTop10 = _users.length > 10 ? _users.skip(10).toList() : <SeriousUser>[];
    
    final myRankIndex = _users.indexWhere((u) => u.id == _currentUser?.id || u.username.toLowerCase() == _currentUser?.username.toLowerCase());
    final isMeOutsideTop10 = _currentUser != null && myRankIndex >= 10;
    final myUserInList = myRankIndex != -1 ? _users[myRankIndex] : _currentUser;

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: const BoxDecoration(
        color: darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 25,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: accentGold.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.emoji_events_rounded,
                      color: Colors.black87, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'LEADERBOARD',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: accentGold.withValues(alpha: 0.4),
                                width: 1,
                              ),
                            ),
                            child: const Text(
                              'TOP 10',
                              style: TextStyle(
                                color: accentGold,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Peringkat produktivitas pemain Mode Serius realtime',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white60),
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
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (top3.isNotEmpty) ...[
                              _buildTop3Podium(top3),
                              const SizedBox(height: 28),
                            ],

                            _buildTop10TableHeader(totalUsers: _users.length),
                            const SizedBox(height: 12),

                            _buildTop10Table(top10),

                            if (isMeOutsideTop10 && myUserInList != null) ...[
                              const SizedBox(height: 16),
                              _buildMyPinnedRankCard(myUserInList, myRankIndex + 1),
                            ],

                            if (beyondTop10.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildBeyondTop10Expansion(beyondTop10),
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
        // Crown & Avatar with Bouncy "Tuing-Tuing" Animation
        _BouncingPodiumAvatar(
          rank: rank,
          crownIcon: crownIcon,
          badgeColor: badgeColor,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: badgeColor, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withValues(alpha: rank == 1 ? 0.45 : 0.3),
                      blurRadius: rank == 1 ? 14 : 10,
                      spreadRadius: rank == 1 ? 1.5 : 0,
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

  /// Header Section untuk Tabel Top 10
  Widget _buildTop10TableHeader({required int totalUsers}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.table_chart_rounded, color: accentGold, size: 16),
          const SizedBox(width: 8),
          const Text(
            'TABEL TOP 10 PENGGUNA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$totalUsers Peserta Terdaftar',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tabel Top 10 Pemain (Menampilkan Rank, Profil, Nama Panggilan, Username, Task Selesai, Total Point)
  Widget _buildTop10Table(List<SeriousUser> topUsers) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header Bar Kolom Tabel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF0B132B),
            child: const Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Text(
                    'RANK',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  flex: 5,
                  child: Text(
                    'PEMAIN & USERNAME',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'TASK',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'POIN',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF334155)),

          // Baris-baris Data Pengguna (Rank 1 - 10)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: topUsers.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              color: Color(0xFF1E293B),
              indent: 12,
              endIndent: 12,
            ),
            itemBuilder: (context, index) {
              final rank = index + 1;
              final user = topUsers[index];
              final isMe = _currentUser != null &&
                  (_currentUser?.id == user.id ||
                      _currentUser?.username.toLowerCase() ==
                          user.username.toLowerCase());

              return _buildTableRowItem(
                rank: rank,
                user: user,
                isMe: isMe,
              );
            },
          ),
        ],
      ),
    );
  }

  /// Desain Baris Individual Tabel
  Widget _buildTableRowItem({
    required int rank,
    required SeriousUser user,
    required bool isMe,
  }) {
    // Styling rank medal / badge
    Color rankColor;
    String? medalEmoji;
    if (rank == 1) {
      rankColor = const Color(0xFFF59E0B);
      medalEmoji = '🥇';
    } else if (rank == 2) {
      rankColor = const Color(0xFFCBD5E1);
      medalEmoji = '🥈';
    } else if (rank == 3) {
      rankColor = const Color(0xFFD97706);
      medalEmoji = '🥉';
    } else {
      rankColor = const Color(0xFF94A3B8);
    }

    final rowBg = isMe
        ? accentGold.withValues(alpha: 0.12)
        : (rank <= 3
            ? rankColor.withValues(alpha: 0.04)
            : Colors.transparent);

    return Container(
      color: rowBg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. RANK BADGE
          SizedBox(
            width: 38,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (medalEmoji != null) ...[
                  Text(medalEmoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 2),
                ],
                Text(
                  '#$rank',
                  style: TextStyle(
                    color: isMe ? accentGold : rankColor,
                    fontWeight: FontWeight.w900,
                    fontSize: rank <= 3 ? 12 : 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // 2. PROFIL, NAMA PANGGILAN & USERNAME
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMe
                              ? accentGold
                              : (rank <= 3 ? rankColor : Colors.white24),
                          width: isMe ? 1.8 : 1.2,
                        ),
                      ),
                      child: _buildAvatar(user, size: 34),
                    ),
                    if (isMe)
                      Positioned(
                        right: -2,
                        bottom: -2,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: accentGold,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.star,
                              size: 8, color: Colors.black),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              user.displayName.isNotEmpty
                                  ? user.displayName
                                  : user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isMe ? accentGold : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4.5, vertical: 1),
                              decoration: BoxDecoration(
                                color: accentGold,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'KAMU',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. TASK SELESAI
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Color(0xFF10B981), size: 11),
                  const SizedBox(width: 3.5),
                  Flexible(
                    child: Text(
                      '${user.totalTasksCompleted}',
                      style: const TextStyle(
                        color: Color(0xFF34D399),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),

          // 4. TOTAL POINT
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentGold.withValues(alpha: isMe ? 0.35 : 0.2),
                    const Color(0xFFD97706).withValues(alpha: isMe ? 0.35 : 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: accentGold.withValues(alpha: isMe ? 0.8 : 0.4),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.bolt_rounded, color: accentGold, size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '${user.totalPoints}',
                    style: TextStyle(
                      color: isMe ? Colors.white : accentGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu Pinned Posisi Pengguna jika Berada di Luar Top 10
  Widget _buildMyPinnedRankCard(SeriousUser user, int myRank) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentGold.withValues(alpha: 0.18),
            cardBg,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentGold, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accentGold.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accentGold,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '#$myRank',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildAvatar(user, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      '(Posisi Kamu)',
                      style: TextStyle(
                        color: accentGold,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  '@${user.username} • ${user.totalTasksCompleted} Task Selesai',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentGold.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentGold.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, color: accentGold, size: 13),
                Text(
                  '${user.totalPoints} PTS',
                  style: const TextStyle(
                    color: accentGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Expandable untuk Peserta di Luar Top 10 (Rank 11+)
  Widget _buildBeyondTop10Expansion(List<SeriousUser> remaining) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF334155), width: 0.8),
        ),
        child: ExpansionTile(
          collapsedIconColor: const Color(0xFF94A3B8),
          iconColor: accentGold,
          title: Text(
            'Lihat Peserta Lainnya (+${remaining.length} Pemain)',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                children: remaining.asMap().entries.map((entry) {
                  final rank = entry.key + 11;
                  final user = entry.value;
                  final isMe = _currentUser != null &&
                      (_currentUser?.id == user.id ||
                          _currentUser?.username.toLowerCase() ==
                              user.username.toLowerCase());
                  return _buildTableRowItem(
                    rank: rank,
                    user: user,
                    isMe: isMe,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
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

/// Widget animasi "Tuing-Tuing" untuk avatar podium Top 3
class _BouncingPodiumAvatar extends StatefulWidget {
  final Widget child;
  final String crownIcon;
  final int rank;
  final Color badgeColor;

  const _BouncingPodiumAvatar({
    required this.child,
    required this.crownIcon,
    required this.rank,
    required this.badgeColor,
  });

  @override
  State<_BouncingPodiumAvatar> createState() => _BouncingPodiumAvatarState();
}

class _BouncingPodiumAvatarState extends State<_BouncingPodiumAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounceAnimation;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();

    // Durasi berbeda tiap rank agar gerakan tuing-tuing terlihat dinamis & tidak kaku bersamaan
    final durationMs = widget.rank == 1
        ? 1200
        : (widget.rank == 2 ? 1450 : 1350);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: durationMs),
    );

    // Ketinggian memantul (Rank 1 melompat lebih tinggi & bangga)
    final bounceHeight = widget.rank == 1
        ? -13.0
        : (widget.rank == 2 ? -9.5 : -8.0);

    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: bounceHeight,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // Goyangan mahkota (Crown tilt tuing-tuing)
    final maxTilt = widget.rank == 1
        ? 0.08
        : (widget.rank == 2 ? -0.06 : 0.06);

    _tiltAnimation = Tween<double>(
      begin: -maxTilt,
      end: maxTilt,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    // Delay start bertahap berdasarkan rank
    Future.delayed(Duration(milliseconds: widget.rank * 150), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value; // 0.0 (bawah/mendarat) -> 1.0 (puncak pantulan)

        // Squash & Stretch cartoonish "Tuing-Tuing":
        // Saat di bawah (mendarat): agak gepeng/squash (scaleY = 0.93, scaleX = 1.07)
        // Saat di puncak (terbang): memanjang/stretch (scaleY = 1.06, scaleX = 0.95)
        final scaleX = 1.07 - (0.12 * t);
        final scaleY = 0.93 + (0.13 * t);
        final yOffset = _bounceAnimation.value;
        final tilt = _tiltAnimation.value;

        // Shadow di bawah avatar yang membesar & mengecil mengikuti tinggi pantulan
        final shadowWidth = (widget.rank == 1 ? 46.0 : 38.0) * (1.1 - 0.28 * t);
        final shadowOpacity = (0.38 - (0.18 * t)).clamp(0.1, 0.45);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mahkota dengan animasi goyang tuing-tuing
            Transform.translate(
              offset: Offset(0, yOffset * 0.45),
              child: Transform.rotate(
                angle: tilt,
                child: Text(
                  widget.crownIcon,
                  style: TextStyle(
                    fontSize: widget.rank == 1 ? 24 : 21,
                    shadows: [
                      Shadow(
                        color: widget.badgeColor.withValues(alpha: 0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),

            // Avatar dengan squash & stretch bounce
            Transform.translate(
              offset: Offset(0, yOffset),
              child: Transform.scale(
                alignment: Alignment.bottomCenter,
                scaleX: scaleX,
                scaleY: scaleY,
                child: widget.child,
              ),
            ),
            const SizedBox(height: 3),

            // Bayangan kontak di atas podium yang dinamis
            Container(
              height: 4,
              width: shadowWidth,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: shadowOpacity),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: widget.badgeColor.withValues(alpha: shadowOpacity * 0.4),
                    blurRadius: 4,
                    spreadRadius: 0.5,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

