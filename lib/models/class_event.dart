/// One class as it appears on the schedule calendar.
///
/// The backend (`GET /api/live/calendar`) has already resolved when a class
/// sits on the grid — including classes started with "go live now", which have
/// no scheduled time and fall back to when they started — so the UI only has to
/// draw what it is given.
class ClassEvent {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final String instructorName;

  /// scheduled | live | ended
  final String status;

  /// public | private
  final String visibility;
  final String joinCode;

  /// Local time. The API sends UTC; these are converted on parse.
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;

  /// False when the time came from a fallback rather than a real booking, so
  /// the UI can avoid promising a start the instructor never set.
  final bool isScheduled;
  final bool isMine;
  final int attendeesCount;
  final String recordingUrl;

  const ClassEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.instructorId,
    required this.instructorName,
    required this.status,
    required this.visibility,
    required this.joinCode,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.isScheduled,
    required this.isMine,
    required this.attendeesCount,
    required this.recordingUrl,
  });

  factory ClassEvent.fromJson(Map<String, dynamic> j) {
    final start = DateTime.tryParse('${j['startAt']}')?.toLocal() ??
        DateTime.now();
    final end = DateTime.tryParse('${j['endAt']}')?.toLocal() ??
        start.add(const Duration(hours: 1));
    return ClassEvent(
      id: '${j['id'] ?? ''}',
      title: '${j['title'] ?? 'Class'}',
      description: '${j['description'] ?? ''}',
      instructorId: '${j['instructorId'] ?? ''}',
      instructorName: '${j['instructorName'] ?? 'Instructor'}',
      status: '${j['status'] ?? 'scheduled'}',
      visibility: '${j['visibility'] ?? 'public'}',
      joinCode: '${j['joinCode'] ?? ''}',
      startAt: start,
      endAt: end,
      durationMinutes: (j['durationMinutes'] as num?)?.round() ??
          end.difference(start).inMinutes,
      isScheduled: j['isScheduled'] == true,
      isMine: j['isMine'] == true,
      attendeesCount: (j['attendeesCount'] as num?)?.toInt() ?? 0,
      recordingUrl: '${j['recordingUrl'] ?? ''}',
    );
  }

  bool get isLive => status == 'live';
  bool get isEnded => status == 'ended';
  bool get isUpcoming => status == 'scheduled';
  bool get isPrivate => visibility == 'private';
  bool get hasRecording => recordingUrl.isNotEmpty;

  /// The class is over in wall-clock terms even if nobody ended it.
  bool get hasPassed => !isLive && endAt.isBefore(DateTime.now());

  /// The map the LiveClass screens still pass around as raw JSON.
  Map<String, dynamic> toLiveClassMap() => {
        '_id': id,
        'title': title,
        'description': description,
        'instructorId': instructorId,
        'instructorName': instructorName,
        'status': status,
        'visibility': visibility,
        'joinCode': joinCode,
        'recordingUrl': recordingUrl,
        'attendeesCount': attendeesCount,
        'scheduledAt': isScheduled ? startAt.toUtc().toIso8601String() : null,
      };
}

/// A window of the calendar: every day in range, plus how many classes each
/// day holds (used for the dots under the date numbers).
class CalendarWindow {
  /// "2026-09-10" -> the classes on that local day, in start order.
  final Map<String, List<ClassEvent>> days;

  /// "2026-09-10" -> class count. Only days with at least one class appear.
  final Map<String, int> counts;

  final int total;

  const CalendarWindow({
    required this.days,
    required this.counts,
    required this.total,
  });

  const CalendarWindow.empty()
      : days = const {},
        counts = const {},
        total = 0;

  factory CalendarWindow.fromJson(Map<String, dynamic> j) {
    final days = <String, List<ClassEvent>>{};
    for (final raw in (j['days'] as List? ?? const [])) {
      final day = Map<String, dynamic>.from(raw as Map);
      final date = '${day['date']}';
      days[date] = (day['events'] as List? ?? const [])
          .map((e) => ClassEvent.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final counts = <String, int>{};
    (j['counts'] as Map?)?.forEach((k, v) {
      counts['$k'] = (v as num?)?.toInt() ?? 0;
    });
    return CalendarWindow(
      days: days,
      counts: counts,
      total: (j['total'] as num?)?.toInt() ?? 0,
    );
  }

  List<ClassEvent> eventsOn(String dayKey) => days[dayKey] ?? const [];

  int countOn(String dayKey) => counts[dayKey] ?? 0;
}

/// "2026-09-10" for a local date — the key format the calendar API uses.
String dayKeyOf(DateTime local) {
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '${local.year}-$m-$d';
}

/// "2026-09" for a local date.
String monthKeyOf(DateTime local) =>
    '${local.year}-${local.month.toString().padLeft(2, '0')}';
