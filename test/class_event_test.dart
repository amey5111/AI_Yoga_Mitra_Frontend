// Tests for the schedule calendar's data layer: parsing what
// GET /api/live/calendar returns, and the day/month keys the UI looks
// events up by. The payload below mirrors the real response shape.

import 'package:flutter_test/flutter_test.dart';

import 'package:yoga_mitra/models/class_event.dart';

Map<String, dynamic> eventJson({
  String id = 'c1',
  String title = 'Morning Flow',
  String status = 'scheduled',
  String visibility = 'public',
  String startAt = '2026-09-10T05:00:00.000Z',
  String endAt = '2026-09-10T06:00:00.000Z',
  int durationMinutes = 60,
  bool isScheduled = true,
  bool isMine = false,
  int attendeesCount = 0,
  String recordingUrl = '',
}) {
  return {
    'id': id,
    'title': title,
    'description': 'Gentle start to the day',
    'instructorId': 'teacher-1',
    'instructorName': 'Asha',
    'status': status,
    'visibility': visibility,
    'joinCode': 'YM-4K2P9',
    'channelName': 'ym-abc',
    'startAt': startAt,
    'endAt': endAt,
    'durationMinutes': durationMinutes,
    'isScheduled': isScheduled,
    'isMine': isMine,
    'attendeesCount': attendeesCount,
    'recordingUrl': recordingUrl,
  };
}

void main() {
  group('ClassEvent', () {
    test('parses the calendar payload', () {
      final e = ClassEvent.fromJson(eventJson());

      expect(e.id, 'c1');
      expect(e.title, 'Morning Flow');
      expect(e.instructorName, 'Asha');
      expect(e.joinCode, 'YM-4K2P9');
      expect(e.durationMinutes, 60);
      expect(e.isScheduled, isTrue);
      expect(e.isUpcoming, isTrue);
      expect(e.isLive, isFalse);
      expect(e.isEnded, isFalse);
      expect(e.isPrivate, isFalse);
      expect(e.hasRecording, isFalse);
    });

    test('converts UTC instants to local time', () {
      final e = ClassEvent.fromJson(eventJson());

      expect(e.startAt.isUtc, isFalse);
      expect(
        e.startAt.toUtc().toIso8601String(),
        '2026-09-10T05:00:00.000Z',
      );
      expect(e.endAt.difference(e.startAt), const Duration(hours: 1));
    });

    test('reads the live and ended states', () {
      final live = ClassEvent.fromJson(
        eventJson(status: 'live', attendeesCount: 12),
      );
      expect(live.isLive, isTrue);
      expect(live.attendeesCount, 12);

      final ended = ClassEvent.fromJson(eventJson(
        status: 'ended',
        recordingUrl: 'https://example.com/replay.mp4',
      ));
      expect(ended.isEnded, isTrue);
      expect(ended.hasRecording, isTrue);
    });

    test('marks a private class', () {
      final e = ClassEvent.fromJson(eventJson(visibility: 'private'));
      expect(e.isPrivate, isTrue);
    });

    test('survives a payload with missing fields', () {
      final e = ClassEvent.fromJson({'id': 'x'});

      expect(e.title, 'Class');
      expect(e.instructorName, 'Instructor');
      expect(e.status, 'scheduled');
      expect(e.visibility, 'public');
      expect(e.isScheduled, isFalse);
      expect(e.isMine, isFalse);
      // With no times, it still yields a usable one-hour slot rather than
      // throwing while the list is being built.
      expect(e.endAt.isAfter(e.startAt), isTrue);
    });

    test('falls back to the start/end gap when duration is absent', () {
      final json = eventJson(
        startAt: '2026-09-10T05:00:00.000Z',
        endAt: '2026-09-10T06:30:00.000Z',
      )..remove('durationMinutes');

      expect(ClassEvent.fromJson(json).durationMinutes, 90);
    });

    test('hasPassed reflects wall-clock time, not status', () {
      final past = ClassEvent.fromJson(eventJson(
        startAt: '2020-01-01T05:00:00.000Z',
        endAt: '2020-01-01T06:00:00.000Z',
      ));
      expect(past.hasPassed, isTrue);

      final future = ClassEvent.fromJson(eventJson(
        startAt: '2099-01-01T05:00:00.000Z',
        endAt: '2099-01-01T06:00:00.000Z',
      ));
      expect(future.hasPassed, isFalse);

      // A class that is on air is never "passed", whatever the clock says.
      final running = ClassEvent.fromJson(eventJson(
        status: 'live',
        startAt: '2020-01-01T05:00:00.000Z',
        endAt: '2020-01-01T06:00:00.000Z',
      ));
      expect(running.hasPassed, isFalse);
    });

    test('converts back to the map the live screens expect', () {
      final map = ClassEvent.fromJson(eventJson()).toLiveClassMap();

      expect(map['_id'], 'c1');
      expect(map['title'], 'Morning Flow');
      expect(map['instructorId'], 'teacher-1');
      expect(map['status'], 'scheduled');
      expect(map['joinCode'], 'YM-4K2P9');
      expect(map['scheduledAt'], '2026-09-10T05:00:00.000Z');
    });

    test('leaves scheduledAt null for a go-live-now class', () {
      final map = ClassEvent.fromJson(
        eventJson(status: 'live', isScheduled: false),
      ).toLiveClassMap();

      expect(map['scheduledAt'], isNull);
    });
  });

  group('CalendarWindow', () {
    final payload = {
      'range': {
        'from': '2026-08-31T18:30:00.000Z',
        'to': '2026-09-30T18:30:00.000Z',
        'tzOffset': 330,
      },
      'counts': {'2026-09-10': 2, '2026-09-15': 1},
      'total': 3,
      'days': [
        {'date': '2026-09-09', 'count': 0, 'events': []},
        {
          'date': '2026-09-10',
          'count': 2,
          'events': [
            eventJson(id: 'a', title: 'Sunrise'),
            eventJson(
              id: 'b',
              title: 'Evening Stretch',
              startAt: '2026-09-10T13:00:00.000Z',
              endAt: '2026-09-10T14:00:00.000Z',
            ),
          ],
        },
        {
          'date': '2026-09-15',
          'count': 1,
          'events': [eventJson(id: 'c', title: 'Breathwork')],
        },
      ],
    };

    test('parses days, counts and totals', () {
      final w = CalendarWindow.fromJson(payload);

      expect(w.total, 3);
      expect(w.days.length, 3);
      expect(w.counts['2026-09-10'], 2);
      expect(w.counts['2026-09-15'], 1);
    });

    test('looks up a day in the order the server sent it', () {
      final w = CalendarWindow.fromJson(payload);
      final tenth = w.eventsOn('2026-09-10');

      expect(tenth.length, 2);
      expect(tenth.map((e) => e.title), ['Sunrise', 'Evening Stretch']);
    });

    test('returns empty results for days with nothing on them', () {
      final w = CalendarWindow.fromJson(payload);

      expect(w.eventsOn('2026-09-09'), isEmpty);
      expect(w.countOn('2026-09-09'), 0);
      // A date outside the window is simply empty, not an error.
      expect(w.eventsOn('2026-12-25'), isEmpty);
      expect(w.countOn('2026-12-25'), 0);
    });

    test('handles a summary response with no event bodies', () {
      final w = CalendarWindow.fromJson({
        'counts': {'2026-09-10': 2},
        'total': 2,
        'days': [
          {'date': '2026-09-10', 'count': 2},
        ],
        'events': [],
      });

      expect(w.total, 2);
      expect(w.countOn('2026-09-10'), 2);
      expect(w.eventsOn('2026-09-10'), isEmpty);
    });

    test('an empty window has no days and no counts', () {
      const w = CalendarWindow.empty();

      expect(w.total, 0);
      expect(w.counts, isEmpty);
      expect(w.eventsOn('2026-09-10'), isEmpty);
    });
  });

  group('date keys', () {
    test('dayKeyOf pads month and day', () {
      expect(dayKeyOf(DateTime(2026, 9, 8)), '2026-09-08');
      expect(dayKeyOf(DateTime(2026, 12, 25)), '2026-12-25');
      expect(dayKeyOf(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('dayKeyOf uses the local date, ignoring the time of day', () {
      expect(dayKeyOf(DateTime(2026, 9, 8, 23, 59)), '2026-09-08');
      expect(dayKeyOf(DateTime(2026, 9, 8, 0, 1)), '2026-09-08');
    });

    test('monthKeyOf matches the month parameter the API takes', () {
      expect(monthKeyOf(DateTime(2026, 9, 30)), '2026-09');
      expect(monthKeyOf(DateTime(2026, 1, 1)), '2026-01');
    });

    test('day keys line up with what the server sent back', () {
      final w = CalendarWindow.fromJson({
        'counts': {'2026-09-10': 1},
        'total': 1,
        'days': [
          {
            'date': '2026-09-10',
            'count': 1,
            'events': [eventJson()],
          },
        ],
      });

      // The grid builds its key from a local DateTime; it must find the day.
      expect(w.eventsOn(dayKeyOf(DateTime(2026, 9, 10))).length, 1);
    });
  });
}
