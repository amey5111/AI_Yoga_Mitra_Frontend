import '../services/api_service.dart';

/// One item in a class's lesson plan: a written note, a timed instruction to
/// follow along with, or a piece of media the instructor attached.
class LessonMaterial {
  final String id;
  final String classId;
  final String instructorId;

  /// note | instruction | link | audio | video | image | pdf
  final String kind;

  final String title;
  final String body;

  /// Either an http(s) link the instructor pasted, or a server path such as
  /// `/uploads/materials/<file>` for something they uploaded.
  final String url;

  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final int durationSeconds;
  final int order;

  /// False while the instructor is still drafting it — students never see
  /// these, and only the owner gets them back from the API at all.
  final bool publishedToStudents;

  const LessonMaterial({
    required this.id,
    required this.classId,
    required this.instructorId,
    required this.kind,
    required this.title,
    required this.body,
    required this.url,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.durationSeconds,
    required this.order,
    required this.publishedToStudents,
  });

  factory LessonMaterial.fromJson(Map<String, dynamic> j) {
    return LessonMaterial(
      id: '${j['id'] ?? ''}',
      classId: '${j['classId'] ?? ''}',
      instructorId: '${j['instructorId'] ?? ''}',
      kind: '${j['kind'] ?? 'note'}',
      title: '${j['title'] ?? ''}',
      body: '${j['body'] ?? ''}',
      url: '${j['url'] ?? ''}',
      fileName: '${j['fileName'] ?? ''}',
      mimeType: '${j['mimeType'] ?? ''}',
      sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      order: (j['order'] as num?)?.toInt() ?? 0,
      publishedToStudents: j['publishedToStudents'] != false,
    );
  }

  bool get isNote => kind == 'note';
  bool get isInstruction => kind == 'instruction';
  bool get isMedia => const ['link', 'audio', 'video', 'image', 'pdf']
      .contains(kind);
  bool get isUploaded => url.startsWith('/uploads/');

  /// Something we can actually hand to a player or a browser.
  ///
  /// Uploads come back as a server-relative path, so they need the API host
  /// in front of them; a pasted link is already absolute.
  String get playableUrl {
    if (url.isEmpty) return '';
    if (!url.startsWith('/')) return url;
    final root = ApiService.rootUrl;
    return '${root.endsWith('/') ? root.substring(0, root.length - 1) : root}'
        '$url';
  }

  /// What to show when the instructor left the title blank.
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    if (fileName.trim().isNotEmpty) return fileName.trim();
    switch (kind) {
      case 'note':
        return 'Note';
      case 'instruction':
        return 'Step';
      case 'audio':
        return 'Audio';
      case 'video':
        return 'Video';
      case 'image':
        return 'Image';
      case 'pdf':
        return 'PDF';
      default:
        return 'Link';
    }
  }

  /// "45 sec" / "2 min" / "1 hr 5 min", or empty when untimed.
  String get durationLabel {
    if (durationSeconds <= 0) return '';
    if (durationSeconds < 60) return '$durationSeconds sec';
    final minutes = durationSeconds ~/ 60;
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours hr' : '$hours hr $rest min';
  }

  /// "1.4 MB" for an uploaded file, empty otherwise.
  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// A whole lesson plan, plus whether the caller owns it.
class LessonPlan {
  final String classId;
  final String classTitle;

  /// True when the API recognised the caller as the class's instructor, which
  /// is what unlocks editing and shows unpublished drafts.
  final bool isOwner;

  final List<LessonMaterial> materials;

  const LessonPlan({
    required this.classId,
    required this.classTitle,
    required this.isOwner,
    required this.materials,
  });

  const LessonPlan.empty()
      : classId = '',
        classTitle = '',
        isOwner = false,
        materials = const [];

  factory LessonPlan.fromJson(Map<String, dynamic> j) {
    return LessonPlan(
      classId: '${j['classId'] ?? ''}',
      classTitle: '${j['classTitle'] ?? ''}',
      isOwner: j['isOwner'] == true,
      materials: (j['materials'] as List? ?? const [])
          .map((e) => LessonMaterial.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  bool get isEmpty => materials.isEmpty;
  int get total => materials.length;

  /// How long the timed steps add up to, for the "≈ 25 min of guided steps"
  /// line at the top of the plan.
  int get totalGuidedSeconds =>
      materials.fold(0, (sum, m) => sum + m.durationSeconds);
}
