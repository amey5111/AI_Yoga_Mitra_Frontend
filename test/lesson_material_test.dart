// The lesson plan's data layer: parsing what /api/live/:id/materials returns,
// and turning a server-relative upload path into something a player can open.

import 'package:flutter_test/flutter_test.dart';

import 'package:yoga_mitra/models/lesson_material.dart';
import 'package:yoga_mitra/services/api_service.dart';

Map<String, dynamic> materialJson({
  String id = 'm1',
  String kind = 'note',
  String title = 'Before we start',
  String body = 'Keep a blanket nearby.',
  String url = '',
  String fileName = '',
  int sizeBytes = 0,
  int durationSeconds = 0,
  int order = 0,
  bool published = true,
}) {
  return {
    'id': id,
    'classId': 'c1',
    'instructorId': 'teacher-1',
    'kind': kind,
    'title': title,
    'body': body,
    'url': url,
    'fileName': fileName,
    'mimeType': '',
    'sizeBytes': sizeBytes,
    'durationSeconds': durationSeconds,
    'order': order,
    'publishedToStudents': published,
  };
}

void main() {
  group('LessonMaterial', () {
    test('parses a note', () {
      final m = LessonMaterial.fromJson(materialJson());

      expect(m.id, 'm1');
      expect(m.kind, 'note');
      expect(m.title, 'Before we start');
      expect(m.isNote, isTrue);
      expect(m.isInstruction, isFalse);
      expect(m.isMedia, isFalse);
      expect(m.publishedToStudents, isTrue);
    });

    test('recognises each media kind', () {
      for (final kind in ['link', 'audio', 'video', 'image', 'pdf']) {
        final m = LessonMaterial.fromJson(
          materialJson(kind: kind, url: 'https://example.com/x'),
        );
        expect(m.isMedia, isTrue, reason: '$kind should be media');
      }
      expect(LessonMaterial.fromJson(materialJson(kind: 'note')).isMedia,
          isFalse);
      expect(
        LessonMaterial.fromJson(materialJson(kind: 'instruction')).isMedia,
        isFalse,
      );
    });

    test('survives a payload with missing fields', () {
      final m = LessonMaterial.fromJson({'id': 'x'});

      expect(m.kind, 'note');
      expect(m.title, '');
      expect(m.body, '');
      expect(m.sizeBytes, 0);
      expect(m.durationSeconds, 0);
      // Anything the server sent us was published, absent a flag saying not.
      expect(m.publishedToStudents, isTrue);
    });

    test('an unpublished draft is flagged', () {
      final m = LessonMaterial.fromJson(materialJson(published: false));
      expect(m.publishedToStudents, isFalse);
    });
  });

  group('playable urls', () {
    test('a pasted link is used as-is', () {
      final m = LessonMaterial.fromJson(
        materialJson(kind: 'video', url: 'https://youtu.be/abc123'),
      );
      expect(m.isUploaded, isFalse);
      expect(m.playableUrl, 'https://youtu.be/abc123');
    });

    test('an upload is resolved against the API host', () {
      final m = LessonMaterial.fromJson(
        materialJson(kind: 'audio', url: '/uploads/materials/abc.mp3'),
      );

      expect(m.isUploaded, isTrue);
      // No doubled slash where the root url and the path meet.
      expect(m.playableUrl.contains('//uploads'), isFalse);
      expect(m.playableUrl.endsWith('/uploads/materials/abc.mp3'), isTrue);
      expect(m.playableUrl.startsWith(ApiService.rootUrl.substring(0, 7)),
          isTrue);
    });

    test('an empty url stays empty', () {
      expect(LessonMaterial.fromJson(materialJson()).playableUrl, '');
    });
  });

  group('display helpers', () {
    test('displayTitle falls back to the file name, then the kind', () {
      expect(
        LessonMaterial.fromJson(materialJson(title: 'Warm up')).displayTitle,
        'Warm up',
      );
      expect(
        LessonMaterial.fromJson(
          materialJson(title: '', kind: 'audio', fileName: 'breathe.mp3'),
        ).displayTitle,
        'breathe.mp3',
      );
      expect(
        LessonMaterial.fromJson(materialJson(title: '', kind: 'video'))
            .displayTitle,
        'Video',
      );
      expect(
        LessonMaterial.fromJson(materialJson(title: '   ')).displayTitle,
        'Note',
      );
    });

    test('durationLabel reads naturally at each scale', () {
      String label(int s) =>
          LessonMaterial.fromJson(materialJson(durationSeconds: s))
              .durationLabel;

      expect(label(0), '');
      expect(label(45), '45 sec');
      expect(label(60), '1 min');
      expect(label(150), '2 min');
      expect(label(3600), '1 hr');
      expect(label(3900), '1 hr 5 min');
    });

    test('sizeLabel scales from bytes to megabytes', () {
      String label(int b) =>
          LessonMaterial.fromJson(materialJson(sizeBytes: b)).sizeLabel;

      expect(label(0), '');
      expect(label(512), '512 B');
      expect(label(2048), '2 KB');
      expect(label(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('LessonPlan', () {
    final payload = {
      'classId': 'c1',
      'classTitle': 'Morning Flow',
      'isOwner': true,
      'total': 3,
      'materials': [
        materialJson(id: 'a', title: 'Read this'),
        materialJson(
          id: 'b',
          kind: 'instruction',
          title: 'Hold downward dog',
          durationSeconds: 45,
        ),
        materialJson(
          id: 'c',
          kind: 'audio',
          title: 'Guided breathing',
          url: '/uploads/materials/x.mp3',
          durationSeconds: 300,
        ),
      ],
    };

    test('parses the plan and keeps the server order', () {
      final plan = LessonPlan.fromJson(payload);

      expect(plan.classTitle, 'Morning Flow');
      expect(plan.isOwner, isTrue);
      expect(plan.total, 3);
      expect(plan.isEmpty, isFalse);
      expect(plan.materials.map((m) => m.id), ['a', 'b', 'c']);
    });

    test('adds up the timed items', () {
      expect(LessonPlan.fromJson(payload).totalGuidedSeconds, 345);
    });

    test('a student payload is not owned', () {
      final plan = LessonPlan.fromJson({
        'classId': 'c1',
        'isOwner': false,
        'materials': [materialJson()],
      });
      expect(plan.isOwner, isFalse);
      expect(plan.total, 1);
    });

    test('an empty plan is safe to render', () {
      const plan = LessonPlan.empty();

      expect(plan.isEmpty, isTrue);
      expect(plan.total, 0);
      expect(plan.totalGuidedSeconds, 0);
      expect(plan.materials, isEmpty);
    });

    test('a plan with no materials key still parses', () {
      final plan = LessonPlan.fromJson({'classId': 'c1'});
      expect(plan.isEmpty, isTrue);
      expect(plan.isOwner, isFalse);
    });
  });
}
