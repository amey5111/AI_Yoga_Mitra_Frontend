import 'package:flutter/material.dart';
import '../services/live_api.dart';
import '../theme/app_theme.dart';
import 'live_broadcast_screen.dart';

/// Instructor creates a class: go live now, or schedule for later.
///
/// Opened from the schedule calendar with [initialDate] set, it starts in
/// "schedule" mode on the day the instructor tapped, so picking a slot on the
/// calendar and filling in the details is one continuous flow.
class CreateLiveClassScreen extends StatefulWidget {
  final DateTime? initialDate;

  const CreateLiveClassScreen({super.key, this.initialDate});

  @override
  State<CreateLiveClassScreen> createState() => _CreateLiveClassScreenState();
}

class _CreateLiveClassScreenState extends State<CreateLiveClassScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();

  late bool _goLiveNow;
  bool _private = false;
  DateTime? _scheduledAt;
  int _durationMinutes = 60;
  String _stageMode = 'webinar';
  bool _saving = false;

  static const _durations = [30, 45, 60, 75, 90, 120];

  @override
  void initState() {
    super.initState();
    final day = widget.initialDate;
    // Arriving from a calendar day means the instructor already chose "later".
    _goLiveNow = day == null;
    if (day != null) _scheduledAt = _defaultSlotOn(day);
  }

  /// A sensible opening time: the next full hour today, 7:00 AM on other days.
  DateTime _defaultSlotOn(DateTime day) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    if (!isToday) return DateTime(day.year, day.month, day.day, 7);
    final next = DateTime(now.year, now.month, now.day, now.hour + 1);
    return next;
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final base = _scheduledAt ?? now.add(const Duration(hours: 1));
    final d = await showDatePicker(
      context: context,
      initialDate: base.isBefore(now) ? now : base,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (t == null) return;
    setState(() {
      _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      _toast('Please enter a title');
      return;
    }
    if (!_goLiveNow && _scheduledAt == null) {
      _toast('Please pick a date and time');
      return;
    }
    if (!_goLiveNow && _scheduledAt!.isBefore(DateTime.now())) {
      _toast('That time has already passed. Pick a later slot.');
      return;
    }
    setState(() => _saving = true);
    try {
      final c = await LiveApi.createClass(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        goLiveNow: _goLiveNow,
        scheduledAt: _goLiveNow ? null : _scheduledAt,
        durationMinutes: _durationMinutes,
        visibility: _private ? 'private' : 'public',
        stageMode: _stageMode,
      );
      if (!mounted) return;
      if (_goLiveNow) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LiveBroadcastScreen(liveClass: c)),
        );
      } else {
        final code = c['joinCode'] ?? '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_private
                ? 'Private class scheduled. Share code: $code'
                : 'Class scheduled. Code: $code'),
            duration: const Duration(seconds: 5),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        _toast(e.toString().replaceAll('Exception: ', ''));
        setState(() => _saving = false);
      }
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _slotLabel(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final period = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month - 1]} ${d.year}  ·  $hour:$minute $period';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: appBar(title: 'New Live Class'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: appInputDecoration(
              label: 'Class title',
              hint: 'Morning Flow',
              prefixIcon: Icons.self_improvement_rounded,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: appInputDecoration(
              label: 'Description (optional)',
              hint: 'What will you cover?',
            ),
          ),
          const SizedBox(height: 18),

          _card(
            child: Column(
              children: [
                SwitchListTile(
                  value: _goLiveNow,
                  activeThumbColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Go live now', style: AppTextStyles.heading3()),
                  subtitle: Text('Turn off to schedule for later',
                      style: AppTextStyles.caption()),
                  onChanged: (v) => setState(() {
                    _goLiveNow = v;
                    if (!v) {
                      _scheduledAt ??= _defaultSlotOn(DateTime.now());
                    }
                  }),
                ),
                if (!_goLiveNow) ...[
                  const Divider(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_rounded,
                        color: AppColors.accent),
                    title: Text(
                      _scheduledAt == null
                          ? 'Pick date and time'
                          : _slotLabel(_scheduledAt!),
                      style: AppTextStyles.bodyMedium(),
                    ),
                    trailing: const Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onTap: _pickDateTime,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('How long is the class?',
                        style: AppTextStyles.heading3()),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _durations
                      .map((m) => AppChip(
                            label: _durationLabel(m),
                            selected: _durationMinutes == m,
                            onTap: () => setState(() => _durationMinutes = m),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 8),
                Text(
                  'Used to block the slot on the schedule calendar.',
                  style: AppTextStyles.caption(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.groups_2_outlined,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text('How will you run it?',
                        style: AppTextStyles.heading3()),
                  ],
                ),
                const SizedBox(height: 12),
                _modeOption(
                  value: 'webinar',
                  icon: Icons.record_voice_over_outlined,
                  title: 'You teach, they watch',
                  subtitle:
                      'Students watch your video and raise a hand to come on '
                      'camera one at a time.',
                ),
                const SizedBox(height: 8),
                _modeOption(
                  value: 'group',
                  icon: Icons.grid_view_rounded,
                  title: 'Everyone on camera',
                  subtitle:
                      'You see the whole class practising in a grid, and they '
                      'see you. Best for small groups.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          _card(
            child: SwitchListTile(
              value: _private,
              activeThumbColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                _private ? Icons.lock_rounded : Icons.public_rounded,
                color: AppColors.accent,
              ),
              title: Text('Private (invite only)',
                  style: AppTextStyles.heading3()),
              subtitle: Text('Only people with the join code can enter',
                  style: AppTextStyles.caption()),
              onChanged: (v) => setState(() => _private = v),
            ),
          ),

          const SizedBox(height: 26),
          AppPrimaryButton(
            label: _goLiveNow ? 'Create and go live' : 'Schedule class',
            icon: _goLiveNow ? Icons.sensors_rounded : Icons.event_available_rounded,
            loading: _saving,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _modeOption({
    required String value,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _stageMode == value;
    return InkWell(
      onTap: () => setState(() => _stageMode = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.chipBg : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon,
                size: 20,
                color: selected ? AppColors.accent : AppColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyMedium()),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTextStyles.caption()),
                ],
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.accent : AppColors.divider,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
