import 'package:daily_apps/models/model_todo.dart';
import 'package:daily_apps/utils/todo_alarm_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TodoAlarmConfig {
  bool enabled;
  String type; // 'interval' | 'specific'
  int intervalMinutes;
  String intervalStartTime;
  String intervalEndTime;
  List<String> specificTimes;
  String soundType; // 'default' | 'custom'
  String defaultSound;
  String? customSoundPath;
  String? customSoundName;

  TodoAlarmConfig({
    required this.enabled,
    required this.type,
    required this.intervalMinutes,
    required this.intervalStartTime,
    required this.intervalEndTime,
    required this.specificTimes,
    required this.soundType,
    required this.defaultSound,
    this.customSoundPath,
    this.customSoundName,
  });

  factory TodoAlarmConfig.fromGroup(TodoDateGroup group) {
    return TodoAlarmConfig(
      enabled: group.reminderEnabled,
      type: group.reminderType,
      intervalMinutes: group.reminderIntervalMinutes,
      intervalStartTime: group.reminderIntervalStartTime,
      intervalEndTime: group.reminderIntervalEndTime,
      specificTimes: List<String>.from(group.reminderSpecificTimes),
      soundType: group.reminderSoundType,
      defaultSound: group.reminderDefaultSound,
      customSoundPath: group.reminderCustomSoundPath,
      customSoundName: group.reminderCustomSoundName,
    );
  }

  void applyToGroup(TodoDateGroup group) {
    group.reminderEnabled = enabled;
    group.reminderType = type;
    group.reminderIntervalMinutes = intervalMinutes;
    group.reminderIntervalStartTime = intervalStartTime;
    group.reminderIntervalEndTime = intervalEndTime;
    group.reminderSpecificTimes = List<String>.from(specificTimes);
    group.reminderSoundType = soundType;
    group.reminderDefaultSound = defaultSound;
    group.reminderCustomSoundPath = customSoundPath;
    group.reminderCustomSoundName = customSoundName;
  }
}

class TodoAlarmSetupSheet extends StatefulWidget {
  final TodoAlarmConfig initialConfig;
  final String dateTitle;

  const TodoAlarmSetupSheet({
    super.key,
    required this.initialConfig,
    required this.dateTitle,
  });

  static Future<TodoAlarmConfig?> show(
    BuildContext context, {
    required TodoAlarmConfig initialConfig,
    required String dateTitle,
  }) {
    return showModalBottomSheet<TodoAlarmConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TodoAlarmSetupSheet(
        initialConfig: initialConfig,
        dateTitle: dateTitle,
      ),
    );
  }

  @override
  State<TodoAlarmSetupSheet> createState() => _TodoAlarmSetupSheetState();
}

class _TodoAlarmSetupSheetState extends State<TodoAlarmSetupSheet> {
  static const Color primaryTerracotta = Color(0xFFBA5A3A);
  static const Color darkTerracotta = Color(0xFF8C3E26);
  static const Color softTerracottaBg = Color(0xFFFDF6F3);

  late String _type; // 'interval' | 'specific'
  late int _intervalMinutes;
  late String _intervalStartTime;
  late String _intervalEndTime;
  late List<String> _specificTimes;
  late String _soundType; // 'default' | 'custom'
  late String _defaultSound;
  String? _customSoundPath;
  String? _customSoundName;

  String? _currentlyPlayingSoundKey; // Untuk tracking preview aktif

  final List<Map<String, dynamic>> _defaultSoundOptions = [
    {
      'id': 'chime_classic',
      'title': 'Chime Klasik',
      'subtitle': 'Harmoni 4 nada lonceng lembut',
      'icon': Icons.notifications_active_rounded,
    },
    {
      'id': 'alarm_digital',
      'title': 'Alarm Digital',
      'subtitle': 'Bunyi beep elektronik ritmis',
      'icon': Icons.alarm_rounded,
    },
    {
      'id': 'gentle_bell',
      'title': 'Bel Lembut',
      'subtitle': 'Suara denting bel yang menenangkan',
      'icon': Icons.music_note_rounded,
    },
    {
      'id': 'cheerful_melody',
      'title': 'Melodi Ceria',
      'subtitle': 'Alunan nada ceria pembangkit semangat',
      'icon': Icons.celebration_rounded,
    },
  ];

  final List<int> _intervalPresets = [15, 30, 60, 120, 180, 240];

  @override
  void initState() {
    super.initState();
    _type = widget.initialConfig.type;
    _intervalMinutes = widget.initialConfig.intervalMinutes;
    _intervalStartTime = widget.initialConfig.intervalStartTime;
    _intervalEndTime = widget.initialConfig.intervalEndTime;
    _specificTimes = List<String>.from(widget.initialConfig.specificTimes);
    _soundType = widget.initialConfig.soundType;
    _defaultSound = widget.initialConfig.defaultSound;
    _customSoundPath = widget.initialConfig.customSoundPath;
    _customSoundName = widget.initialConfig.customSoundName;
  }

  @override
  void dispose() {
    TodoAlarmService.stopPreview();
    super.dispose();
  }

  Future<void> _togglePreview(String soundKey, {String? customPath}) async {
    HapticFeedback.selectionClick();
    if (_currentlyPlayingSoundKey == soundKey) {
      await TodoAlarmService.stopPreview();
      setState(() {
        _currentlyPlayingSoundKey = null;
      });
    } else {
      setState(() {
        _currentlyPlayingSoundKey = soundKey;
      });
      if (soundKey == 'custom') {
        await TodoAlarmService.playPreview(
          soundType: 'custom',
          customPath: customPath,
        );
      } else {
        await TodoAlarmService.playPreview(
          soundType: 'default',
          defaultSound: soundKey,
        );
      }
    }
  }

  Future<void> _pickCustomMp3() async {
    HapticFeedback.lightImpact();
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;

        setState(() {
          _soundType = 'custom';
          _customSoundPath = path;
          _customSoundName = name;
        });

        // Test play sound
        _togglePreview('custom', customPath: path);
      }
    } catch (e) {
      debugPrint('Error picking audio file: $e');
    }
  }

  Future<void> _pickTimeFor(bool isStartTime) async {
    final currentStr = isStartTime ? _intervalStartTime : _intervalEndTime;
    final parts = currentStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTerracotta,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStartTime) {
          _intervalStartTime = formatted;
        } else {
          _intervalEndTime = formatted;
        }
      });
    }
  }

  Future<void> _addSpecificTime() async {
    HapticFeedback.lightImpact();
    const defaultTime = TimeOfDay(hour: 12, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: defaultTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryTerracotta,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!_specificTimes.contains(formatted)) {
        setState(() {
          _specificTimes.add(formatted);
          _specificTimes.sort();
        });
      }
    }
  }

  void _saveAndClose() {
    HapticFeedback.mediumImpact();
    TodoAlarmService.stopPreview();

    // Validasi jam spesifik
    if (_type == 'specific' && _specificTimes.isEmpty) {
      _specificTimes = ['09:00', '13:00', '19:00'];
    }

    final result = TodoAlarmConfig(
      enabled: true,
      type: _type,
      intervalMinutes: _intervalMinutes,
      intervalStartTime: _intervalStartTime,
      intervalEndTime: _intervalEndTime,
      specificTimes: _specificTimes,
      soundType: _soundType,
      defaultSound: _defaultSound,
      customSoundPath: _customSoundPath,
      customSoundName: _customSoundName,
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: primaryTerracotta.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.alarm_on_rounded,
                    color: primaryTerracotta,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Set Up Pengingat & Alarm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Section: ${widget.dateTitle}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    TodoAlarmService.stopPreview();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. MODE SELECTION (Segmented Switch)
                  const Text(
                    'PILIH METODE PENGINGAT',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildModeTab(
                            title: 'Interval Waktu',
                            subtitle: 'Tiap X jam/menit',
                            icon: Icons.timer_outlined,
                            isSelected: _type == 'interval',
                            onTap: () {
                              setState(() => _type = 'interval');
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildModeTab(
                            title: 'Jam Spesifik',
                            subtitle: 'Pilih jam tertentu',
                            icon: Icons.schedule_rounded,
                            isSelected: _type == 'specific',
                            onTap: () {
                              setState(() => _type = 'specific');
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. MODE CONFIGURATION BODY
                  if (_type == 'interval') _buildIntervalConfigSection(),
                  if (_type == 'specific') _buildSpecificTimesConfigSection(),

                  const SizedBox(height: 24),

                  // 3. SOUND SELECTION SECTION
                  const Text(
                    'PILIH SUARA ALARM / NADA DERING',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Default Sounds List
                  ..._defaultSoundOptions.map((sound) {
                    final isSelected =
                        _soundType == 'default' && _defaultSound == sound['id'];
                    final isPlaying = _currentlyPlayingSoundKey == sound['id'];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? softTerracottaBg : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? primaryTerracotta.withValues(alpha: 0.6)
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 1.6 : 1,
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          setState(() {
                            _soundType = 'default';
                            _defaultSound = sound['id'] as String;
                          });
                          _togglePreview(sound['id'] as String);
                        },
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryTerracotta
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            sound['icon'] as IconData,
                            color: isSelected ? Colors.white : const Color(0xFF64748B),
                            size: 18,
                          ),
                        ),
                        title: Text(
                          sound['title'] as String,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? darkTerracotta : const Color(0xFF1E293B),
                          ),
                        ),
                        subtitle: Text(
                          sound['subtitle'] as String,
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected
                                ? primaryTerracotta.withValues(alpha: 0.85)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                isPlaying
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_fill_rounded,
                                color: isPlaying ? primaryTerracotta : const Color(0xFF94A3B8),
                                size: 28,
                              ),
                              onPressed: () {
                                _togglePreview(sound['id'] as String);
                              },
                            ),
                            Radio<String>(
                              value: sound['id'] as String,
                              groupValue: _soundType == 'default' ? _defaultSound : null,
                              activeColor: primaryTerracotta,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _soundType = 'default';
                                    _defaultSound = val;
                                  });
                                  _togglePreview(val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),

                  // Custom MP3 Picker Option
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _soundType == 'custom'
                          ? softTerracottaBg
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _soundType == 'custom'
                            ? primaryTerracotta.withValues(alpha: 0.6)
                            : const Color(0xFFE2E8F0),
                        width: _soundType == 'custom' ? 1.6 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _soundType == 'custom'
                                    ? primaryTerracotta
                                    : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.folder_special_rounded,
                                color: _soundType == 'custom'
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pilih Sound Pribadi (.mp3)',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    'Gunakan lagu atau rekaman suara sendiri',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Radio<String>(
                              value: 'custom',
                              groupValue: _soundType,
                              activeColor: primaryTerracotta,
                              onChanged: (_) {
                                if (_customSoundPath != null) {
                                  setState(() => _soundType = 'custom');
                                } else {
                                  _pickCustomMp3();
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_customSoundName != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primaryTerracotta.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.audio_file_rounded,
                                  color: primaryTerracotta,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _customSoundName!,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _currentlyPlayingSoundKey == 'custom'
                                        ? Icons.stop_circle_rounded
                                        : Icons.play_circle_fill_rounded,
                                    color: primaryTerracotta,
                                    size: 24,
                                  ),
                                  onPressed: () {
                                    _togglePreview('custom', customPath: _customSoundPath);
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _pickCustomMp3,
                            icon: const Icon(
                              Icons.file_upload_outlined,
                              size: 18,
                              color: primaryTerracotta,
                            ),
                            label: Text(
                              _customSoundName == null
                                  ? 'Pilih File .mp3 dari Memori'
                                  : 'Ganti File .mp3',
                              style: const TextStyle(
                                color: primaryTerracotta,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(
                                color: primaryTerracotta.withValues(alpha: 0.4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Info looping 5 menit
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFDE68A),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFD97706),
                          size: 20,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Saat waktu alarm tiba, alarm akan berdering looping selama 5 menit & menampilkan pop-up daftar tugas yang belum selesai hingga Anda klik "Iyaa tau".',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF92400E),
                              height: 1.4,
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

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saveAndClose,
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                label: const Text(
                  'Simpan Pengingat',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryTerracotta,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeTab({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryTerracotta : const Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? darkTerracotta : const Color(0xFF475569),
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? primaryTerracotta : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntervalConfigSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ulangi Setiap:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _intervalPresets.map((mins) {
              final isSel = _intervalMinutes == mins;
              String label;
              if (mins < 60) {
                label = '$mins Menit';
              } else {
                final h = mins ~/ 60;
                label = '$h Jam';
              }

              return ChoiceChip(
                label: Text(label),
                selected: isSel,
                selectedColor: primaryTerracotta,
                backgroundColor: Colors.white,
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                  color: isSel ? Colors.white : const Color(0xFF475569),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: isSel
                        ? primaryTerracotta
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _intervalMinutes = mins);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          const Text(
            'Rentang Jam Operasional Pengingat:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Mulai Jam',
                  timeStr: _intervalStartTime,
                  onTap: () => _pickTimeFor(true),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.arrow_forward_rounded, color: Color(0xFF94A3B8), size: 18),
              ),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Selesai Jam',
                  timeStr: _intervalEndTime,
                  onTap: () => _pickTimeFor(false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificTimesConfigSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Daftar Jam Pengingat:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                ),
              ),
              TextButton.icon(
                onPressed: _addSpecificTime,
                icon: const Icon(Icons.add_circle_outline_rounded, size: 16, color: primaryTerracotta),
                label: const Text(
                  'Tambah Jam',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: primaryTerracotta,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_specificTimes.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              alignment: Alignment.center,
              child: const Text(
                'Belum ada jam yang ditambahkan.\nKlik tombol "+ Tambah Jam" di atas.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  height: 1.4,
                ),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _specificTimes.map((time) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.access_time_filled_rounded,
                        size: 14,
                        color: primaryTerracotta,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        time,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() {
                            _specificTimes.remove(time);
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 15,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required String timeStr,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Icon(
                  Icons.edit_rounded,
                  size: 15,
                  color: primaryTerracotta,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
