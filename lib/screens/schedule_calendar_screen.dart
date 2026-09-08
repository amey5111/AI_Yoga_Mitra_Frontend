import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/class_event.dart';
import '../services/live_api.dart';
import '../theme/app_theme.dart';
import '../utils/language_helper.dart';
import 'create_live_class_screen.dart';
import 'live_broadcast_screen.dart';
import 'live_watch_screen.dart';
import 'recorded_replay_screen.dart';

/// Who is looking at the schedule.
enum ScheduleMode {
  /// An instructor's own classes, private ones included, with editing.
  instructor,

  /// The public schedule of everything happening on the platform.
  browse,
}

/// Month grid + day agenda for scheduled classes.
///
/// One tap moves between days, the dots under each date say how busy it is,
/// and the list below is that day's timetable. Instructors get the same view
/// with editing on top: schedule onto a chosen day, move a class, go live.
class ScheduleCalendarScreen extends StatefulWidget {
  final ScheduleMode mode;

  const ScheduleCalendarScreen({super.key, this.mode = ScheduleMode.browse});

  @override
  State<ScheduleCalendarScreen> createState() => _ScheduleCalendarScreenState();
}

class _ScheduleCalendarScreenState extends State<ScheduleCalendarScreen> {
  static const _live = Color(0xFFE53935);

  late DateTime _visibleMonth;
  late DateTime _selectedDay;

  /// monthKey ("2026-09") -> that month's classes. Kept so flicking back and
  /// forth between months does not re-fetch what we already have.
  final Map<String, CalendarWindow> _cache = {};

  bool _loading = true;
  String? _error;
  String _myId = '';
  String _filter = 'all'; // all | scheduled | live | ended

  bool get _isInstructor => widget.mode == ScheduleMode.instructor;

  String get _monthKey => monthKeyOf(_visibleMonth);

  CalendarWindow get _window =>
      _cache[_monthKey] ?? const CalendarWindow.empty();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _selectedDay = DateTime(now.year, now.month, now.day);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final p = await SharedPreferences.getInstance();
    _myId = p.getString('userId') ?? '';
    await _loadMonth();
  }

  Future<void> _loadMonth({bool force = false}) async {
    final key = _monthKey;
    if (!force && _cache.containsKey(key)) {
      setState(() {
        _loading = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final window = await LiveApi.calendarMonth(
        _visibleMonth,
        instructorId: _isInstructor ? _myId : null,
        viewerId: _myId,
      );
      if (!mounted) return;
      setState(() {
        _cache[key] = window;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  Future<void> _refresh() => _loadMonth(force: true);

  void _goToMonth(DateTime month) {
    setState(() {
      _visibleMonth = DateTime(month.year, month.month);
      // Keep the selection inside the month being shown.
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      final day = _selectedDay.day > lastDay ? lastDay : _selectedDay.day;
      _selectedDay = DateTime(month.year, month.month, day);
    });
    _loadMonth();
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = DateTime(now.year, now.month, now.day);
    });
    _loadMonth();
  }

  /// The selected day's classes, after the status filter.
  List<ClassEvent> get _agenda {
    final all = _window.eventsOn(dayKeyOf(_selectedDay));
    if (_filter == 'all') return all;
    return all.where((e) => e.status == _filter).toList();
  }

  String _t(String en, String mr, String hi) => LanguageHelper.t(en, mr, hi);

  /* ── actions ────────────────────────────────────────────────────────────── */

  Future<void> _createOn(DateTime day) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateLiveClassScreen(initialDate: day),
      ),
    );
    if (created == true) await _refresh();
  }

  Future<void> _openEvent(ClassEvent e) async {
    if (e.isLive) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => e.isMine
              ? LiveBroadcastScreen(liveClass: e.toLiveClassMap())
              : LiveWatchScreen(liveClass: e.toLiveClassMap()),
        ),
      );
      await _refresh();
      return;
    }
    if (e.isEnded) {
      if (!e.hasRecording) {
        _toast(_t('No recording for this class.', 'या वर्गाचे रेकॉर्डिंग नाही.',
            'इस क्लास की रिकॉर्डिंग नहीं है।'));
        return;
      }
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              RecordedReplayScreen(title: e.title, url: e.recordingUrl),
        ),
      );
      return;
    }
    _showDetails(e);
  }

  Future<void> _goLive(ClassEvent e) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveBroadcastScreen(
          liveClass: e.toLiveClassMap(),
          autoGoLive: true,
        ),
      ),
    );
    await _refresh();
  }

  Future<void> _reschedule(ClassEvent e) async {
    final date = await showDatePicker(
      context: context,
      initialDate: e.startAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: _t('Move class to', 'वर्ग हलवा', 'क्लास कब करें'),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(e.startAt),
    );
    if (time == null || !mounted) return;

    final minutes = await _pickDuration(e.durationMinutes);
    if (minutes == null || !mounted) return;

    final when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    try {
      await LiveApi.reschedule(e.id, scheduledAt: when, durationMinutes: minutes);
      if (!mounted) return;
      setState(() {
        _visibleMonth = DateTime(when.year, when.month);
        _selectedDay = DateTime(when.year, when.month, when.day);
      });
      // The class may have moved out of the month we had cached.
      _cache.clear();
      await _refresh();
      if (!mounted) return;
      _toast(_t('Class moved.', 'वर्ग हलवला.', 'क्लास बदल दी गई।'));
    } catch (err) {
      if (!mounted) return;
      _toast(err.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<int?> _pickDuration(int current) {
    const options = [30, 45, 60, 75, 90, 120];
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('How long?', 'किती वेळ?', 'कितनी देर?'),
                style: AppTextStyles.heading2()),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: options
                  .map((m) => AppChip(
                        label: _durationLabel(m),
                        selected: m == current,
                        onTap: () => Navigator.pop(context, m),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelClass(ClassEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Cancel this class?', 'हा वर्ग रद्द करायचा?',
            'यह क्लास रद्द करें?')),
        content: Text(_t(
          'It will be removed from the schedule for everyone.',
          'तो सर्वांच्या वेळापत्रकातून काढला जाईल.',
          'यह सभी के शेड्यूल से हट जाएगी।',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Keep it', 'राहू द्या', 'रहने दें')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _live),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Cancel class', 'वर्ग रद्द करा', 'क्लास रद्द करें')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await LiveApi.cancelClass(e.id);
    await _refresh();
    if (!mounted) return;
    _toast(_t('Class cancelled.', 'वर्ग रद्द केला.', 'क्लास रद्द कर दी गई।'));
  }

  void _copyCode(String code) {
    if (code.isEmpty) return;
    Clipboard.setData(ClipboardData(text: code));
    _toast('${_t('Code copied', 'कोड कॉपी झाला', 'कोड कॉपी हुआ')}: $code');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /* ── build ──────────────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: appBar(
        title: _isInstructor
            ? _t('My Schedule', 'माझे वेळापत्रक', 'मेरा शेड्यूल')
            : _t('Class Schedule', 'वर्ग वेळापत्रक', 'क्लास शेड्यूल'),
        actions: [
          IconButton(
            tooltip: _t('Today', 'आज', 'आज'),
            icon: const Icon(Icons.today_rounded),
            onPressed: _goToToday,
          ),
        ],
      ),
      floatingActionButton: _isInstructor
          ? FloatingActionButton.extended(
              onPressed: () => _createOn(_selectedDay),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('Schedule', 'वेळ ठरवा', 'शेड्यूल करें'),
                  style: AppTextStyles.button()),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.accent,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            _monthCard(),
            const SizedBox(height: 16),
            _filterRow(),
            const SizedBox(height: 14),
            _dayHeader(),
            const SizedBox(height: 10),
            if (_error != null)
              _errorBox(_error!)
            else if (_loading && !_cache.containsKey(_monthKey))
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (_agenda.isEmpty)
              _emptyDay()
            else
              ..._agenda.map(_eventTile),
          ],
        ),
      ),
    );
  }

  /* ── month grid ─────────────────────────────────────────────────────────── */

  Widget _monthCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.card,
      ),
      child: GestureDetector(
        // Swipe the grid to change month, the way a calendar app behaves.
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v < -200) {
            _goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1));
          } else if (v > 200) {
            _goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1));
          }
        },
        child: Column(
          children: [
            _monthHeader(),
            const SizedBox(height: 10),
            _weekdayRow(),
            const SizedBox(height: 4),
            _dayGrid(),
          ],
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Row(
      children: [
        _arrow(
          Icons.chevron_left_rounded,
          () => _goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month - 1)),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                '${_monthName(_visibleMonth.month)} ${_visibleMonth.year}',
                style: AppTextStyles.heading2(),
              ),
              const SizedBox(height: 2),
              Text(
                _window.total == 0
                    ? _t('No classes', 'वर्ग नाहीत', 'कोई क्लास नहीं')
                    : '${_window.total} ${_window.total == 1 ? _t('class', 'वर्ग', 'क्लास') : _t('classes', 'वर्ग', 'क्लासेस')}',
                style: AppTextStyles.caption(),
              ),
            ],
          ),
        ),
        _arrow(
          Icons.chevron_right_rounded,
          () => _goToMonth(DateTime(_visibleMonth.year, _visibleMonth.month + 1)),
        ),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 26, color: AppColors.accent),
        ),
      ),
    );
  }

  Widget _weekdayRow() {
    final labels = _weekdayLabels();
    return Row(
      children: List.generate(
        7,
        (i) => Expanded(
          child: Center(
            child: Text(labels[i], style: AppTextStyles.label()),
          ),
        ),
      ),
    );
  }

  Widget _dayGrid() {
    final first = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    // Sunday-first grid: DateTime.weekday is 1 (Mon) .. 7 (Sun).
    final leading = first.weekday % 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: List.generate(rows, (row) {
        return Row(
          children: List.generate(7, (col) {
            final dayNumber = row * 7 + col - leading + 1;
            if (dayNumber < 1 || dayNumber > daysInMonth) {
              return const Expanded(child: SizedBox(height: 50));
            }
            return Expanded(
              child: _dayCell(
                DateTime(_visibleMonth.year, _visibleMonth.month, dayNumber),
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _dayCell(DateTime day) {
    final events = _window.eventsOn(dayKeyOf(day));
    final selected = _isSameDay(day, _selectedDay);
    final today = _isSameDay(day, DateTime.now());

    return InkWell(
      onTap: () => setState(() => _selectedDay = day),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 50,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.transparent,
                shape: BoxShape.circle,
                border: today && !selected
                    ? Border.all(color: AppColors.accent, width: 1.4)
                    : null,
              ),
              child: Text(
                '${day.day}',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight:
                      selected || today ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : today
                          ? AppColors.accent
                          : AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 3),
            _dots(events, selected),
          ],
        ),
      ),
    );
  }

  /// Up to three dots under a date, coloured by what is on that day.
  Widget _dots(List<ClassEvent> events, bool selected) {
    if (events.isEmpty) return const SizedBox(height: 6);
    final shown = events.take(3).toList();
    return SizedBox(
      height: 6,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: shown.map((e) {
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: selected ? Colors.white : _statusColor(e),
              shape: BoxShape.circle,
            ),
          );
        }).toList(),
      ),
    );
  }

  /* ── filters and day header ─────────────────────────────────────────────── */

  Widget _filterRow() {
    final filters = <String, String>{
      'all': _t('All', 'सर्व', 'सभी'),
      'scheduled': _t('Upcoming', 'येणारे', 'आगामी'),
      'live': _t('Live', 'लाइव्ह', 'लाइव'),
      'ended': _t('Finished', 'झालेले', 'समाप्त'),
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: AppChip(
              label: entry.value,
              selected: _filter == entry.key,
              onTap: () => setState(() => _filter = entry.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _dayHeader() {
    final count = _agenda.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_relativeDayLabel(_selectedDay),
                  style: AppTextStyles.label(color: AppColors.accent)),
              const SizedBox(height: 2),
              Text(
                '${_weekdayName(_selectedDay.weekday)}, ${_selectedDay.day} ${_monthName(_selectedDay.month)}',
                style: AppTextStyles.heading2(),
              ),
            ],
          ),
        ),
        if (count > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text(
              count == 1
                  ? '1 ${_t('class', 'वर्ग', 'क्लास')}'
                  : '$count ${_t('classes', 'वर्ग', 'क्लासेस')}',
              style: AppTextStyles.caption(),
            ),
          ),
      ],
    );
  }

  /* ── agenda ─────────────────────────────────────────────────────────────── */

  Widget _eventTile(ClassEvent e) {
    final color = _statusColor(e);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => _openEvent(e),
          onLongPress: e.isMine && e.isUpcoming ? () => _showDetails(e) : null,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 58,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.isScheduled || e.isLive
                            ? _timeLabel(e.startAt)
                            : '--:--',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_durationLabel(e.durationMinutes),
                          style: AppTextStyles.caption()),
                    ],
                  ),
                ),
                Container(
                  width: 3,
                  height: 46,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading3(),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _subtitleOf(e),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption(),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _tag(_statusLabel(e), color),
                          if (e.isPrivate)
                            _tag(_t('Private', 'खाजगी', 'निजी'),
                                AppColors.textSecondary,
                                icon: Icons.lock_outline_rounded),
                          if (e.isEnded && e.hasRecording)
                            _tag(_t('Recording', 'रेकॉर्डिंग', 'रिकॉर्डिंग'),
                                AppColors.accent,
                                icon: Icons.play_circle_outline_rounded),
                        ],
                      ),
                    ],
                  ),
                ),
                if (e.isMine && e.isUpcoming)
                  IconButton(
                    tooltip: _t('Options', 'पर्याय', 'विकल्प'),
                    icon: const Icon(Icons.more_vert_rounded,
                        color: AppColors.textSecondary),
                    onPressed: () => _showDetails(e),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.chevron_right_rounded,
                        color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyDay() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: AppColors.chipBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.self_improvement_rounded,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            _filter == 'all'
                ? _t('Nothing scheduled', 'काहीही ठरलेले नाही',
                    'कुछ शेड्यूल नहीं है')
                : _t('Nothing here', 'इथे काही नाही', 'यहाँ कुछ नहीं है'),
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 6),
          Text(
            _isInstructor
                ? _t('Tap Schedule to add a class on this day.',
                    'या दिवशी वर्ग जोडण्यासाठी वेळ ठरवा दाबा.',
                    'इस दिन क्लास जोड़ने के लिए शेड्यूल दबाएँ।')
                : _t('Check another day for upcoming classes.',
                    'येणाऱ्या वर्गांसाठी दुसरा दिवस पहा.',
                    'आगामी क्लासेस के लिए दूसरा दिन देखें।'),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          if (_isInstructor) ...[
            const SizedBox(height: 16),
            AppSecondaryButton(
              label: _t('Schedule a class', 'वर्ग ठरवा', 'क्लास शेड्यूल करें'),
              icon: Icons.add_rounded,
              onPressed: () => _createOn(_selectedDay),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded,
              color: AppColors.textSecondary, size: 28),
          const SizedBox(height: 10),
          Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(color: AppColors.textSecondary)),
          const SizedBox(height: 14),
          AppSecondaryButton(
            label: _t('Try again', 'पुन्हा प्रयत्न', 'फिर कोशिश करें'),
            icon: Icons.refresh_rounded,
            onPressed: _refresh,
          ),
        ],
      ),
    );
  }

  /* ── details sheet ──────────────────────────────────────────────────────── */

  void _showDetails(ClassEvent e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(e.title, style: AppTextStyles.heading2())),
                _tag(_statusLabel(e), _statusColor(e)),
              ],
            ),
            const SizedBox(height: 4),
            Text(_subtitleOf(e), style: AppTextStyles.caption()),
            const SizedBox(height: 16),
            _detailRow(
              Icons.event_rounded,
              _t('When', 'कधी', 'कब'),
              '${_weekdayName(e.startAt.weekday)}, ${e.startAt.day} ${_monthName(e.startAt.month)} · ${_timeLabel(e.startAt)}',
            ),
            _detailRow(Icons.timer_outlined, _t('Length', 'कालावधी', 'अवधि'),
                _durationLabel(e.durationMinutes)),
            if (e.description.isNotEmpty)
              _detailRow(Icons.notes_rounded,
                  _t('About', 'माहिती', 'जानकारी'), e.description),
            if (e.joinCode.isNotEmpty)
              _detailRow(Icons.vpn_key_rounded,
                  _t('Join code', 'जॉइन कोड', 'जॉइन कोड'), e.joinCode),
            const SizedBox(height: 18),
            if (e.isMine && e.isUpcoming) ...[
              AppPrimaryButton(
                label: _t('Go live now', 'आता लाइव्ह व्हा', 'अभी लाइव जाएँ'),
                icon: Icons.sensors_rounded,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _goLive(e);
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: _t('Move', 'हलवा', 'बदलें'),
                      icon: Icons.edit_calendar_rounded,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _reschedule(e);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppSecondaryButton(
                      label: _t('Copy code', 'कोड कॉपी', 'कोड कॉपी'),
                      icon: Icons.copy_rounded,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _copyCode(e.joinCode);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppSecondaryButton(
                label: _t('Cancel class', 'वर्ग रद्द करा', 'क्लास रद्द करें'),
                icon: Icons.delete_outline_rounded,
                textColor: _live,
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _cancelClass(e);
                },
              ),
            ] else if (e.isUpcoming) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.notifications_active_outlined,
                        color: AppColors.accent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _startsInLabel(e.startAt),
                        style: AppTextStyles.bodyMedium(
                            color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              if (e.joinCode.isNotEmpty) ...[
                const SizedBox(height: 10),
                AppSecondaryButton(
                  label: _t('Copy join code', 'जॉइन कोड कॉपी',
                      'जॉइन कोड कॉपी करें'),
                  icon: Icons.copy_rounded,
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    _copyCode(e.joinCode);
                  },
                ),
              ],
            ],
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Widget _sheet({required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.accent),
          const SizedBox(width: 12),
          SizedBox(width: 88, child: Text(label, style: AppTextStyles.caption())),
          Expanded(
            child: Text(value,
                style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /* ── labels ─────────────────────────────────────────────────────────────── */

  Color _statusColor(ClassEvent e) {
    if (e.isLive) return _live;
    if (e.isEnded) return AppColors.textSecondary;
    return AppColors.accent;
  }

  String _statusLabel(ClassEvent e) {
    if (e.isLive) return _t('LIVE', 'लाइव्ह', 'लाइव');
    if (e.isEnded) return _t('Finished', 'झाले', 'समाप्त');
    if (e.hasPassed) return _t('Missed', 'चुकले', 'छूट गई');
    return _t('Upcoming', 'येणारा', 'आगामी');
  }

  String _subtitleOf(ClassEvent e) {
    final parts = <String>[
      '${_t('with', 'सह', 'के साथ')} ${e.instructorName}',
      if (e.isLive && e.attendeesCount > 0)
        '${e.attendeesCount} ${_t('watching', 'पाहत आहेत', 'देख रहे हैं')}',
      if (e.isEnded && e.attendeesCount > 0)
        '${e.attendeesCount} ${_t('joined', 'सामील झाले', 'शामिल हुए')}',
    ];
    return parts.join('  •  ');
  }

  String _timeLabel(DateTime d) {
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  String _durationLabel(int minutes) {
    if (minutes < 60) return '$minutes ${_t('min', 'मिनिटे', 'मिनट')}';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final hLabel = '$h ${_t('hr', 'तास', 'घंटा')}';
    return m == 0 ? hLabel : '$hLabel $m ${_t('min', 'मिनिटे', 'मिनट')}';
  }

  String _startsInLabel(DateTime start) {
    final diff = start.difference(DateTime.now());
    if (diff.isNegative) {
      return _t('This class has already started.', 'हा वर्ग सुरू झाला आहे.',
          'यह क्लास शुरू हो चुकी है।');
    }
    if (diff.inMinutes < 60) {
      return '${_t('Starts in', 'सुरू होईल', 'शुरू होगी')} ${diff.inMinutes} ${_t('min', 'मिनिटांत', 'मिनट में')}';
    }
    if (diff.inHours < 24) {
      return '${_t('Starts in', 'सुरू होईल', 'शुरू होगी')} ${diff.inHours} ${_t('hr', 'तासांत', 'घंटे में')}';
    }
    return '${_t('Starts in', 'सुरू होईल', 'शुरू होगी')} ${diff.inDays} ${_t('days', 'दिवसांत', 'दिन में')}';
  }

  String _relativeDayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = DateTime(day.year, day.month, day.day).difference(today).inDays;
    if (diff == 0) return _t('TODAY', 'आज', 'आज');
    if (diff == 1) return _t('TOMORROW', 'उद्या', 'कल');
    if (diff == -1) return _t('YESTERDAY', 'काल', 'कल');
    if (diff > 1) return '${_t('IN', '', '')} $diff ${_t('DAYS', 'दिवसांनी', 'दिन बाद')}'.trim();
    return '${-diff} ${_t('DAYS AGO', 'दिवसांपूर्वी', 'दिन पहले')}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<String> _weekdayLabels() => [
        _t('SUN', 'रवि', 'रवि'),
        _t('MON', 'सोम', 'सोम'),
        _t('TUE', 'मंगळ', 'मंगल'),
        _t('WED', 'बुध', 'बुध'),
        _t('THU', 'गुरु', 'गुरु'),
        _t('FRI', 'शुक्र', 'शुक्र'),
        _t('SAT', 'शनि', 'शनि'),
      ];

  String _weekdayName(int weekday) {
    const en = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    const mr = [
      'सोमवार', 'मंगळवार', 'बुधवार', 'गुरुवार',
      'शुक्रवार', 'शनिवार', 'रविवार',
    ];
    const hi = [
      'सोमवार', 'मंगलवार', 'बुधवार', 'गुरुवार',
      'शुक्रवार', 'शनिवार', 'रविवार',
    ];
    final i = (weekday - 1).clamp(0, 6);
    return _t(en[i], mr[i], hi[i]);
  }

  String _monthName(int month) {
    const en = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    const mr = [
      'जानेवारी', 'फेब्रुवारी', 'मार्च', 'एप्रिल', 'मे', 'जून',
      'जुलै', 'ऑगस्ट', 'सप्टेंबर', 'ऑक्टोबर', 'नोव्हेंबर', 'डिसेंबर',
    ];
    const hi = [
      'जनवरी', 'फ़रवरी', 'मार्च', 'अप्रैल', 'मई', 'जून',
      'जुलाई', 'अगस्त', 'सितंबर', 'अक्टूबर', 'नवंबर', 'दिसंबर',
    ];
    final i = (month - 1).clamp(0, 11);
    return _t(en[i], mr[i], hi[i]);
  }
}
