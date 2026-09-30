import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/admin_api.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'admin_instructor_profile_screen.dart';
import 'live_watch_screen.dart';
import 'recorded_replay_screen.dart';
import 'welcome_screen.dart';

/// Admin / recruiter console (only instructor@yogamitra.in reaches this).
/// Sees every instructor with their live/online status, every class from every
/// instructor, and can join any class. Normal instructors never see this.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _accent = AppColors.accent;
  static const _liveRed = Color(0xFFE53935);

  bool _loading = true;
  bool _error = false;
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _instructors = [];
  List<Map<String, dynamic>> _classes = [];
  int _tab = 0; // 0 = instructors, 1 = classes
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    _load();
    // Keep live/online status fresh without a manual pull.
    _refresh =
        Timer.periodic(const Duration(seconds: 20), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        AdminApi.overview(),
        AdminApi.instructors(),
        AdminApi.classes(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _instructors = results[1] as List<Map<String, dynamic>>;
        _classes = results[2] as List<Map<String, dynamic>>;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _logout() async {
    await ApiService.clearSession();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  List<Map<String, dynamic>> get _filteredInstructors {
    if (_query.isEmpty) return _instructors;
    final q = _query.toLowerCase();
    return _instructors.where((i) {
      return (i['name'] ?? '').toString().toLowerCase().contains(q) ||
          (i['email'] ?? '').toString().toLowerCase().contains(q) ||
          (i['specialty'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredClasses {
    if (_query.isEmpty) return _classes;
    final q = _query.toLowerCase();
    return _classes.where((c) {
      return (c['title'] ?? '').toString().toLowerCase().contains(q) ||
          (c['instructorName'] ?? '').toString().toLowerCase().contains(q) ||
          (c['joinCode'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  // ── Actions ────────────────────────────────────────────────────────────
  void _joinLive(Map<String, dynamic> liveClass) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LiveWatchScreen(liveClass: Map<String, dynamic>.from(liveClass)),
      ),
    );
  }

  void _openInstructorProfile(Map<String, dynamic> i) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminInstructorProfileScreen(instructor: i),
      ),
    );
  }

  void _openClass(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString();
    if (status == 'live') {
      _joinLive(c);
    } else if (status == 'ended' &&
        (c['recordingUrl'] ?? '').toString().isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordedReplayScreen(
            title: (c['title'] ?? 'Class').toString(),
            url: c['recordingUrl'].toString(),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == 'scheduled'
              ? 'This class has not started yet.'
              : 'No recording available for this class.'),
        ),
      );
    }
  }

  // ── Small building blocks ──────────────────────────────────────────────
  Widget _avatar(String photo, String name, {double size = 46}) {
    if (photo.isNotEmpty) {
      try {
        final b64 = photo.contains(',') ? photo.split(',').last : photo;
        return CircleAvatar(
          radius: size / 2,
          backgroundImage: MemoryImage(base64Decode(b64)),
        );
      } catch (_) {}
    }
    final letter = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.chipBg,
      child: Text(
        letter,
        style: GoogleFonts.poppins(
          color: _accent,
          fontWeight: FontWeight.w700,
          fontSize: size / 2.4,
        ),
      ),
    );
  }

  Widget _statusPill(bool isLive, bool online) {
    late Color c;
    late String label;
    if (isLive) {
      c = _liveRed;
      label = 'LIVE';
    } else if (online) {
      c = AppColors.success;
      label = 'Online';
    } else {
      c = AppColors.textSecondary;
      label = 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _statCard(String label, dynamic value, IconData icon, Color color) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            '${value ?? 0}',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(label, style: AppTextStyles.caption()),
        ],
      ),
    );
  }

  // ── Rows ───────────────────────────────────────────────────────────────
  Widget _instructorRow(Map<String, dynamic> i) {
    final name = (i['name'] ?? 'Instructor').toString();
    final specialty = (i['specialty'] ?? '').toString();
    final email = (i['email'] ?? '').toString();
    final isLive = i['isLive'] == true;
    final online = i['online'] == true;
    final isAdmin = i['isAdmin'] == true;
    final total = i['totalClasses'] ?? 0;
    final liveClass = i['liveClass'];

    return GestureDetector(
      onTap: () => _openInstructorProfile(i),
      behavior: HitTestBehavior.opaque,
      child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _avatar(i['photo']?.toString() ?? '', name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: AppTextStyles.heading3(),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isAdmin) ...[
                          const SizedBox(width: 6),
                          _chip('ADMIN', _accent),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      specialty.isNotEmpty ? specialty : email,
                      style: AppTextStyles.caption(),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusPill(isLive, online),
                  const SizedBox(height: 6),
                  Text('$total classes', style: AppTextStyles.caption()),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppColors.textSecondary),
                ],
              ),
            ],
          ),
          if (isLive && liveClass != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _liveRed,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () =>
                    _joinLive(Map<String, dynamic>.from(liveClass as Map)),
                icon: const Icon(Icons.sensors_rounded, size: 18),
                label: Text(
                  'Join Live Class',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }

  Widget _classRow(Map<String, dynamic> c) {
    final title = (c['title'] ?? 'Class').toString();
    final instructor = (c['instructorName'] ?? 'Instructor').toString();
    final status = (c['status'] ?? '').toString();
    final visibility = (c['visibility'] ?? 'public').toString();
    final joinCode = (c['joinCode'] ?? '').toString();
    final hasRecording = (c['recordingUrl'] ?? '').toString().isNotEmpty;

    Color statusColor;
    if (status == 'live') {
      statusColor = _liveRed;
    } else if (status == 'scheduled') {
      statusColor = AppColors.warning;
    } else {
      statusColor = AppColors.textSecondary;
    }

    final canOpen = status == 'live' || (status == 'ended' && hasRecording);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.heading3(),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text('by $instructor', style: AppTextStyles.caption()),
                  ],
                ),
              ),
              _chip(status.toUpperCase(), statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip(
                visibility == 'private' ? 'PRIVATE' : 'PUBLIC',
                visibility == 'private' ? AppColors.warning : AppColors.success,
              ),
              if (joinCode.isNotEmpty) _chip(joinCode, _accent),
              if (hasRecording) _chip('RECORDED', AppColors.textSecondary),
            ],
          ),
          if (canOpen) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: status == 'live' ? _liveRed : _accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => _openClass(c),
                icon: Icon(
                  status == 'live'
                      ? Icons.sensors_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                ),
                label: Text(
                  status == 'live' ? 'Join Live' : 'Watch Recording',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index, int count) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _accent : AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? _accent : AppColors.divider),
            boxShadow: sel ? AppShadows.button : AppShadows.soft,
          ),
          child: Text(
            '$label ($count)',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: sel ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final instructors = _filteredInstructors;
    final classes = _filteredClasses;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: Column(
            children: [
              // ── Header ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 18),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 26),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Console',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Recruiter view · all instructors & classes',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _load(),
                      icon: const Icon(Icons.refresh_rounded,
                          color: Colors.white),
                      tooltip: 'Refresh',
                    ),
                    IconButton(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded,
                          color: Colors.white),
                      tooltip: 'Log out',
                    ),
                  ],
                ),
              ),

              if (_loading)
                const Expanded(child: AppLoadingIndicator())
              else if (_error)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 46, color: AppColors.textSecondary),
                        const SizedBox(height: 12),
                        Text('Could not load the console.',
                            style: AppTextStyles.body()),
                        const SizedBox(height: 14),
                        AppPrimaryButton(
                          label: 'Retry',
                          icon: Icons.refresh_rounded,
                          width: 160,
                          onPressed: () => _load(),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      // Overview stats
                      SizedBox(
                        height: 92,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            _statCard('Instructors',
                                _overview['totalInstructors'],
                                Icons.groups_rounded, _accent),
                            _statCard('Online now',
                                _overview['onlineInstructors'],
                                Icons.circle, AppColors.success),
                            _statCard('Live now', _overview['liveClasses'],
                                Icons.sensors_rounded, _liveRed),
                            _statCard('Classes', _overview['totalClasses'],
                                Icons.event_note_rounded, AppColors.warning),
                            _statCard('Students', _overview['totalStudents'],
                                Icons.person_rounded, AppColors.textSecondary),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Search
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (v) => setState(() => _query = v),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: _tab == 0
                                ? 'Search instructors by name…'
                                : 'Search classes by title, instructor, code…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _query.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _query = '');
                                    },
                                  ),
                            filled: true,
                            fillColor: AppColors.bgCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Tabs
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            _tabButton('Instructors', 0, instructors.length),
                            _tabButton('Classes', 1, classes.length),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () => _load(),
                          child: _tab == 0
                              ? (instructors.isEmpty
                                  ? _emptyList('No instructors found.')
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      itemCount: instructors.length,
                                      itemBuilder: (_, idx) =>
                                          _instructorRow(instructors[idx]),
                                    ))
                              : (classes.isEmpty
                                  ? _emptyList('No classes found.')
                                  : ListView.builder(
                                      padding:
                                          const EdgeInsets.only(bottom: 24),
                                      itemCount: classes.length,
                                      itemBuilder: (_, idx) =>
                                          _classRow(classes[idx]),
                                    )),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyList(String msg) {
    // ListView so RefreshIndicator still works when the result set is empty.
    return ListView(
      children: [
        const SizedBox(height: 80),
        Center(
          child: Text(msg, style: AppTextStyles.caption()),
        ),
      ],
    );
  }
}
