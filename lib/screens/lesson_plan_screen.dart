import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lesson_material.dart';
import '../services/live_api.dart';
import '../theme/app_theme.dart';
import '../utils/language_helper.dart';
import 'audio_material_screen.dart';
import 'recorded_replay_screen.dart';

/// The lesson plan for a class.
///
/// One screen serves both sides. A student gets a read-only running order of
/// notes, timed steps and media. The instructor who owns the class gets the
/// same list plus the tools to build it: add items, upload audio or video,
/// reorder by dragging, keep something as a draft, and delete.
///
/// Which one you get is decided by the server, not by a flag passed in here —
/// the API only reports `isOwner` when the caller really owns the class.
class LessonPlanScreen extends StatefulWidget {
  final String classId;
  final String classTitle;

  const LessonPlanScreen({
    super.key,
    required this.classId,
    this.classTitle = '',
  });

  @override
  State<LessonPlanScreen> createState() => _LessonPlanScreenState();
}

class _LessonPlanScreenState extends State<LessonPlanScreen> {
  LessonPlan _plan = const LessonPlan.empty();
  bool _loading = true;
  bool _busy = false;
  String? _error;
  String _myId = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final p = await SharedPreferences.getInstance();
      _myId = p.getString('userId') ?? '';
      final plan = await LiveApi.lessonPlan(
        widget.classId,
        instructorId: _myId,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
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

  bool get _canEdit => _plan.isOwner;

  String _t(String en, String mr, String hi) => LanguageHelper.t(en, mr, hi);

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Run an API call with the screen locked, surfacing whatever went wrong.
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
      if (done != null) _toast(done);
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /* ── editing ────────────────────────────────────────────────────────────── */

  Future<void> _addItem(String kind) async {
    final result = await _showItemEditor(kind: kind);
    if (result == null) return;
    await _run(
      () => LiveApi.addMaterial(
        widget.classId,
        kind: kind,
        title: result.title,
        body: result.body,
        url: result.url,
        durationSeconds: result.durationSeconds,
        publishedToStudents: result.published,
      ),
      done: _t('Added to the plan.', 'योजनेत जोडले.', 'प्लान में जोड़ा गया।'),
    );
  }

  Future<void> _editItem(LessonMaterial m) async {
    final result = await _showItemEditor(kind: m.kind, existing: m);
    if (result == null) return;
    await _run(
      () => LiveApi.updateMaterial(
        widget.classId,
        m.id,
        title: result.title,
        body: result.body,
        url: m.isUploaded ? null : result.url,
        durationSeconds: result.durationSeconds,
        publishedToStudents: result.published,
      ),
      done: _t('Saved.', 'जतन झाले.', 'सहेजा गया।'),
    );
  }

  Future<void> _uploadFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
      withData: false,
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    _toast(_t('Uploading...', 'अपलोड होत आहे...', 'अपलोड हो रहा है...'));
    await _run(
      () => LiveApi.uploadMaterial(widget.classId, filePath: path),
      done: _t('Uploaded.', 'अपलोड झाले.', 'अपलोड हो गया।'),
    );
  }

  Future<void> _togglePublished(LessonMaterial m) async {
    await _run(
      () => LiveApi.updateMaterial(
        widget.classId,
        m.id,
        publishedToStudents: !m.publishedToStudents,
      ),
      done: m.publishedToStudents
          ? _t('Hidden from students.', 'विद्यार्थ्यांपासून लपवले.',
              'छात्रों से छिपाया गया।')
          : _t('Visible to students.', 'विद्यार्थ्यांना दिसेल.',
              'छात्रों को दिखेगा।'),
    );
  }

  Future<void> _deleteItem(LessonMaterial m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(_t('Remove this item?', 'हे काढायचे?', 'इसे हटाएँ?')),
        content: Text(m.displayTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('Keep', 'ठेवा', 'रखें')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('Remove', 'काढा', 'हटाएँ')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => LiveApi.deleteMaterial(widget.classId, m.id),
      done: _t('Removed.', 'काढले.', 'हटा दिया।'),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final items = [..._plan.materials];
    final moved = items.removeAt(oldIndex);
    items.insert(newIndex, moved);

    // Show the new order straight away; the server call confirms it.
    setState(() {
      _plan = LessonPlan(
        classId: _plan.classId,
        classTitle: _plan.classTitle,
        isOwner: _plan.isOwner,
        materials: items,
      );
    });

    try {
      await LiveApi.reorderMaterials(
        widget.classId,
        items.map((m) => m.id).toList(),
      );
    } catch (e) {
      _toast(e.toString().replaceAll('Exception: ', ''));
      await _load(); // put it back the way the server has it
    }
  }

  /* ── opening media ──────────────────────────────────────────────────────── */

  Future<void> _open(LessonMaterial m) async {
    if (!m.isMedia || m.playableUrl.isEmpty) {
      if (_canEdit) _editItem(m);
      return;
    }
    switch (m.kind) {
      case 'video':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordedReplayScreen(
              title: m.displayTitle,
              url: m.playableUrl,
            ),
          ),
        );
        return;
      case 'audio':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AudioMaterialScreen(
              title: m.displayTitle,
              subtitle: m.body,
              url: m.playableUrl,
            ),
          ),
        );
        return;
      case 'image':
        _showImage(m);
        return;
      default:
        await _launch(m.playableUrl);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      _toast(_t('Could not open that link.', 'ही लिंक उघडता आली नाही.',
          'यह लिंक नहीं खुल सकी।'));
    }
  }

  void _showImage(LessonMaterial m) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InteractiveViewer(
              child: Image.network(
                m.playableUrl,
                errorBuilder: (context, error, stack) => Padding(
                  padding: const EdgeInsets.all(30),
                  child: Text(
                    _t('Could not load this image.',
                        'ही प्रतिमा लोड झाली नाही.', 'यह इमेज लोड नहीं हुई।'),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('Close', 'बंद करा', 'बंद करें')),
            ),
          ],
        ),
      ),
    );
  }

  /* ── build ──────────────────────────────────────────────────────────────── */

  @override
  Widget build(BuildContext context) {
    final title = _plan.classTitle.isNotEmpty
        ? _plan.classTitle
        : (widget.classTitle.isNotEmpty
            ? widget.classTitle
            : _t('Lesson plan', 'धडा योजना', 'लेसन प्लान'));

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: appBar(title: title),
      floatingActionButton: _canEdit
          ? FloatingActionButton.extended(
              onPressed: _busy ? null : _showAddSheet,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(_t('Add', 'जोडा', 'जोड़ें'),
                  style: AppTextStyles.button()),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _error != null
              ? _errorBox(_error!)
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.accent,
                  child: _body(),
                ),
    );
  }

  Widget _body() {
    if (_plan.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [_header(), const SizedBox(height: 16), _empty()],
      );
    }

    if (!_canEdit) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(),
          const SizedBox(height: 14),
          ..._plan.materials.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _itemCard(e.value, e.key),
                ),
              ),
        ],
      );
    }

    // Owner: the list is draggable, so the header rides above it.
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: _header(),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
            itemCount: _plan.materials.length,
            onReorder: _onReorder,
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 6,
              borderRadius: BorderRadius.circular(18),
              child: child,
            ),
            itemBuilder: (context, index) {
              final m = _plan.materials[index];
              return Padding(
                key: ValueKey(m.id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _itemCard(m, index, draggableIndex: index),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _header() {
    final guided = _plan.totalGuidedSeconds;
    final parts = <String>[
      _plan.total == 1
          ? '1 ${_t('item', 'गोष्ट', 'आइटम')}'
          : '${_plan.total} ${_t('items', 'गोष्टी', 'आइटम')}',
      if (guided > 0)
        '${_t('about', 'सुमारे', 'लगभग')} ${(guided / 60).ceil()} ${_t('min guided', 'मिनिटे मार्गदर्शन', 'मिनट गाइडेड')}',
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.cardGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                _t('Lesson plan', 'धडा योजना', 'लेसन प्लान'),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _plan.isEmpty
                ? (_canEdit
                    ? _t('Add notes, steps and media to guide your students.',
                        'विद्यार्थ्यांना मार्गदर्शन करण्यासाठी नोट्स, पायऱ्या आणि मीडिया जोडा.',
                        'छात्रों का मार्गदर्शन करने के लिए नोट्स, स्टेप्स और मीडिया जोड़ें।')
                    : _t('The instructor has not added anything yet.',
                        'शिक्षकांनी अजून काही जोडलेले नाही.',
                        'इंस्ट्रक्टर ने अभी कुछ नहीं जोड़ा है।'))
                : parts.join('  •  '),
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(LessonMaterial m, int index, {int? draggableIndex}) {
    final color = _kindColor(m.kind);
    final hidden = !m.publishedToStudents;

    return Opacity(
      opacity: hidden ? 0.62 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppShadows.soft,
          border: hidden
              ? Border.all(color: AppColors.divider, width: 1.4)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: () => _open(m),
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: m.isInstruction
                        ? Text(
                            '${index + 1}',
                            style: GoogleFonts.poppins(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          )
                        : Icon(_kindIcon(m.kind), color: color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.displayTitle, style: AppTextStyles.heading3()),
                        if (m.body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            m.body,
                            maxLines: m.isNote ? 6 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.body(
                                color: AppColors.textSecondary),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tag(_kindLabel(m.kind), color),
                            if (m.durationLabel.isNotEmpty)
                              _tag(m.durationLabel, AppColors.textSecondary,
                                  icon: Icons.timer_outlined),
                            if (m.sizeLabel.isNotEmpty)
                              _tag(m.sizeLabel, AppColors.textSecondary),
                            if (hidden)
                              _tag(_t('Draft', 'मसुदा', 'ड्राफ्ट'),
                                  AppColors.warning,
                                  icon: Icons.visibility_off_outlined),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (_canEdit)
                    Column(
                      children: [
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded,
                              color: AppColors.textSecondary),
                          onSelected: (v) {
                            if (v == 'edit') _editItem(m);
                            if (v == 'publish') _togglePublished(m);
                            if (v == 'delete') _deleteItem(m);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(_t('Edit', 'संपादित करा', 'एडिट')),
                            ),
                            PopupMenuItem(
                              value: 'publish',
                              child: Text(hidden
                                  ? _t('Show to students', 'विद्यार्थ्यांना दाखवा',
                                      'छात्रों को दिखाएँ')
                                  : _t('Keep as draft', 'मसुदा ठेवा',
                                      'ड्राफ्ट रखें')),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(_t('Remove', 'काढा', 'हटाएँ')),
                            ),
                          ],
                        ),
                        if (draggableIndex != null)
                          ReorderableDragStartListener(
                            index: draggableIndex,
                            child: const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.drag_handle_rounded,
                                  color: AppColors.textSecondary, size: 20),
                            ),
                          ),
                      ],
                    )
                  else if (m.isMedia)
                    const Padding(
                      padding: EdgeInsets.only(top: 6, right: 6),
                      child: Icon(Icons.play_circle_outline_rounded,
                          color: AppColors.accent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
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
            child: const Icon(Icons.menu_book_rounded,
                color: AppColors.accent, size: 26),
          ),
          const SizedBox(height: 14),
          Text(
            _t('Nothing here yet', 'अजून काही नाही', 'अभी कुछ नहीं है'),
            style: AppTextStyles.heading3(),
          ),
          const SizedBox(height: 6),
          Text(
            _canEdit
                ? _t(
                    'Add a note, a set of steps, or attach audio and video for your students to follow.',
                    'नोट, पायऱ्या जोडा किंवा विद्यार्थ्यांसाठी ऑडिओ आणि व्हिडिओ जोडा.',
                    'नोट, स्टेप्स जोड़ें या छात्रों के लिए ऑडियो और वीडियो अटैच करें।')
                : _t('The instructor has not shared a plan for this class.',
                    'शिक्षकांनी या वर्गासाठी योजना दिलेली नाही.',
                    'इंस्ट्रक्टर ने इस क्लास के लिए प्लान साझा नहीं किया है।'),
            textAlign: TextAlign.center,
            style: AppTextStyles.body(color: AppColors.textSecondary),
          ),
          if (_canEdit) ...[
            const SizedBox(height: 16),
            AppSecondaryButton(
              label: _t('Add the first item', 'पहिली गोष्ट जोडा',
                  'पहला आइटम जोड़ें'),
              icon: Icons.add_rounded,
              onPressed: _showAddSheet,
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorBox(String message) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
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
                onPressed: _load,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /* ── add sheet ──────────────────────────────────────────────────────────── */

  void _showAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _sheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_t('Add to the plan', 'योजनेत जोडा', 'प्लान में जोड़ें'),
                style: AppTextStyles.heading2()),
            const SizedBox(height: 12),
            _addOption(
              sheetContext,
              Icons.sticky_note_2_outlined,
              _t('Note', 'नोंद', 'नोट'),
              _t('Something for students to read',
                  'विद्यार्थ्यांनी वाचण्यासाठी', 'छात्रों के पढ़ने के लिए'),
              () => _addItem('note'),
            ),
            _addOption(
              sheetContext,
              Icons.format_list_numbered_rounded,
              _t('Instruction', 'सूचना', 'निर्देश'),
              _t('A step to follow, with a time',
                  'वेळेसह एक पायरी', 'समय के साथ एक स्टेप'),
              () => _addItem('instruction'),
            ),
            _addOption(
              sheetContext,
              Icons.upload_file_rounded,
              _t('Upload audio or video', 'ऑडिओ किंवा व्हिडिओ अपलोड करा',
                  'ऑडियो या वीडियो अपलोड करें'),
              _t('From this device, up to 25 MB',
                  'या डिव्हाइसवरून, २५ MB पर्यंत',
                  'इस डिवाइस से, 25 MB तक'),
              _uploadFile,
            ),
            _addOption(
              sheetContext,
              Icons.link_rounded,
              _t('Link', 'लिंक', 'लिंक'),
              _t('YouTube, an article, anything on the web',
                  'यूट्यूब, लेख, वेबवरील काहीही',
                  'यूट्यूब, आर्टिकल, वेब पर कुछ भी'),
              () => _addItem('link'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addOption(
    BuildContext sheetContext,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.accent, size: 20),
      ),
      title: Text(title, style: AppTextStyles.heading3()),
      subtitle: Text(subtitle, style: AppTextStyles.caption()),
      onTap: () {
        Navigator.pop(sheetContext);
        onTap();
      },
    );
  }

  /* ── item editor ────────────────────────────────────────────────────────── */

  Future<_ItemDraft?> _showItemEditor({
    required String kind,
    LessonMaterial? existing,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final bodyCtrl = TextEditingController(text: existing?.body ?? '');
    final urlCtrl = TextEditingController(text: existing?.url ?? '');
    int seconds = existing?.durationSeconds ?? 0;
    bool published = existing?.publishedToStudents ?? true;

    final needsUrl = const ['link', 'audio', 'video', 'image', 'pdf']
            .contains(kind) &&
        !(existing?.isUploaded ?? false);
    final isStep = kind == 'instruction';

    return showModalBottomSheet<_ItemDraft>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setLocal) => _sheet(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existing == null
                      ? '${_t('New', 'नवीन', 'नया')} ${_kindLabel(kind).toLowerCase()}'
                      : _t('Edit item', 'संपादित करा', 'आइटम एडिट करें'),
                  style: AppTextStyles.heading2(),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: appInputDecoration(
                    label: _t('Title', 'शीर्षक', 'शीर्षक'),
                    hint: isStep ? 'Hold downward dog' : 'Before we start',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bodyCtrl,
                  maxLines: kind == 'note' ? 6 : 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: appInputDecoration(
                    label: kind == 'note'
                        ? _t('Note', 'नोंद', 'नोट')
                        : _t('Details (optional)', 'तपशील (ऐच्छिक)',
                            'विवरण (वैकल्पिक)'),
                  ),
                ),
                if (needsUrl) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlCtrl,
                    keyboardType: TextInputType.url,
                    decoration: appInputDecoration(
                      label: _t('Link', 'लिंक', 'लिंक'),
                      hint: 'https://youtu.be/...',
                      prefixIcon: Icons.link_rounded,
                    ),
                  ),
                ],
                if (isStep) ...[
                  const SizedBox(height: 16),
                  Text(_t('How long?', 'किती वेळ?', 'कितनी देर?'),
                      style: AppTextStyles.heading3()),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [0, 30, 45, 60, 90, 120, 300].map((s) {
                      return AppChip(
                        label: s == 0
                            ? _t('No timer', 'वेळ नाही', 'कोई टाइमर नहीं')
                            : (s < 60 ? '$s sec' : '${s ~/ 60} min'),
                        selected: seconds == s,
                        onTap: () => setLocal(() => seconds = s),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  value: published,
                  activeThumbColor: AppColors.accent,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      _t('Visible to students', 'विद्यार्थ्यांना दिसेल',
                          'छात्रों को दिखेगा'),
                      style: AppTextStyles.bodyMedium()),
                  subtitle: Text(
                      _t('Turn off to keep it as a draft',
                          'मसुदा ठेवण्यासाठी बंद करा',
                          'ड्राफ्ट रखने के लिए बंद करें'),
                      style: AppTextStyles.caption()),
                  onChanged: (v) => setLocal(() => published = v),
                ),
                const SizedBox(height: 12),
                AppPrimaryButton(
                  label: existing == null
                      ? _t('Add', 'जोडा', 'जोड़ें')
                      : _t('Save', 'जतन करा', 'सहेजें'),
                  onPressed: () {
                    Navigator.pop(
                      sheetContext,
                      _ItemDraft(
                        title: titleCtrl.text.trim(),
                        body: bodyCtrl.text.trim(),
                        url: urlCtrl.text.trim(),
                        durationSeconds: seconds,
                        published: published,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      titleCtrl.dispose();
      bodyCtrl.dispose();
      urlCtrl.dispose();
    });
  }

  /* ── small pieces ───────────────────────────────────────────────────────── */

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

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'instruction':
        return Icons.format_list_numbered_rounded;
      case 'audio':
        return Icons.headphones_rounded;
      case 'video':
        return Icons.play_circle_outline_rounded;
      case 'image':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'link':
        return Icons.link_rounded;
      default:
        return Icons.sticky_note_2_outlined;
    }
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'instruction':
        return AppColors.accent;
      case 'audio':
        return const Color(0xFF00897B);
      case 'video':
        return const Color(0xFFE53935);
      case 'image':
        return const Color(0xFF8E24AA);
      case 'pdf':
        return const Color(0xFFF4511E);
      case 'link':
        return const Color(0xFF1E88E5);
      default:
        return AppColors.indigoDark;
    }
  }

  String _kindLabel(String kind) {
    switch (kind) {
      case 'instruction':
        return _t('Step', 'पायरी', 'स्टेप');
      case 'audio':
        return _t('Audio', 'ऑडिओ', 'ऑडियो');
      case 'video':
        return _t('Video', 'व्हिडिओ', 'वीडियो');
      case 'image':
        return _t('Image', 'प्रतिमा', 'इमेज');
      case 'pdf':
        return _t('PDF', 'PDF', 'PDF');
      case 'link':
        return _t('Link', 'लिंक', 'लिंक');
      default:
        return _t('Note', 'नोंद', 'नोट');
    }
  }
}

/// What the editor sheet hands back.
class _ItemDraft {
  final String title;
  final String body;
  final String url;
  final int durationSeconds;
  final bool published;

  const _ItemDraft({
    required this.title,
    required this.body,
    required this.url,
    required this.durationSeconds,
    required this.published,
  });
}
