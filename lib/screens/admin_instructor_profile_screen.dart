import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/live_api.dart';
import '../theme/app_theme.dart';
import 'live_watch_screen.dart';
import 'recorded_replay_screen.dart';

/// Read-only profile of any instructor, opened from the admin console.
/// Shows their name, photo, bio, specialty, status and stats, plus every
/// class they have run — and lets the admin join any of them.
class AdminInstructorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> instructor;
  const AdminInstructorProfileScreen({super.key, required this.instructor});

  @override
  State<AdminInstructorProfileScreen> createState() =>
      _AdminInstructorProfileScreenState();
}

class _AdminInstructorProfileScreenState
    extends State<AdminInstructorProfileScreen> {
  static const _accent = AppColors.accent;
  static const _liveRed = Color(0xFFE53935);

  bool _loading = true;
  Map<String, dynamic> _profile = {};
  Map<String, dynamic> _stats = {};
  List _classes = [];

  String get _id => widget.instructor['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        LiveApi.getProfile(_id),
        LiveApi.instructorStats(_id),
        LiveApi.myClasses(_id),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _stats = results[1] as Map<String, dynamic>;
        _classes = results[2] as List;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _pick(String key, String fallback) {
    final a = (_profile[key] ?? '').toString();
    if (a.isNotEmpty) return a;
    final b = (widget.instructor[key] ?? '').toString();
    return b.isNotEmpty ? b : fallback;
  }

  void _openClass(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString();
    if (status == 'live') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              LiveWatchScreen(liveClass: Map<String, dynamic>.from(c)),
        ),
      );
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

  Widget _avatar(String photo, String name, {double size = 82}) {
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
      backgroundColor: Colors.white,
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

  Widget _statTile(String label, dynamic value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 20),
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

  Widget _classTile(Map<String, dynamic> c) {
    final status = (c['status'] ?? '').toString();
    final visibility = (c['visibility'] ?? 'public').toString();
    final hasRecording = (c['recordingUrl'] ?? '').toString().isNotEmpty;
    Color statusColor = status == 'live'
        ? _liveRed
        : status == 'scheduled'
            ? AppColors.warning
            : AppColors.textSecondary;
    final canOpen = status == 'live' || (status == 'ended' && hasRecording);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      title: Text((c['title'] ?? 'Class').toString(),
          style: AppTextStyles.bodyMedium(), overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status.toUpperCase(),
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
          const SizedBox(width: 6),
          Text(visibility == 'private' ? 'Private' : 'Public',
              style: AppTextStyles.caption()),
        ],
      ),
      trailing: canOpen
          ? TextButton(
              onPressed: () => _openClass(c),
              child: Text(status == 'live' ? 'Join' : 'Watch'),
            )
          : null,
      onTap: canOpen ? () => _openClass(c) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _pick('name', 'Instructor');
    final specialty = _pick('specialty', '');
    final bio = _pick('bio', '');
    final email = (widget.instructor['email'] ?? '').toString();
    final photo = _pick('photo', '');
    final isLive = widget.instructor['isLive'] == true;
    final online = widget.instructor['online'] == true;
    final liveClass = widget.instructor['liveClass'];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.softBg),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                decoration: const BoxDecoration(
                  gradient: AppGradients.welcomeBg,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                        const Spacer(),
                        Text('Instructor Profile',
                            style: GoogleFonts.inter(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600)),
                        const Spacer(),
                        const SizedBox(width: 38),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _avatar(photo, name),
                    const SizedBox(height: 12),
                    Text(name,
                        style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                    if (specialty.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(specialty,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.85))),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isLive
                                  ? _liveRed
                                  : online
                                      ? const Color(0xFF7CFF9B)
                                      : Colors.white54,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isLive
                                ? 'Live now'
                                : online
                                    ? 'Online'
                                    : 'Offline',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: _loading
                    ? const AppLoadingIndicator()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          if (isLive && liveClass != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _liveRed,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => _openClass(
                                    Map<String, dynamic>.from(liveClass as Map)),
                                icon: const Icon(Icons.sensors_rounded),
                                label: Text('Join Their Live Class',
                                    style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Contact
                          if (email.isNotEmpty)
                            _infoRow(Icons.email_outlined, 'Email', email),

                          // Bio
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text('About', style: AppTextStyles.heading3()),
                            const SizedBox(height: 6),
                            Text(bio, style: AppTextStyles.body()),
                          ],

                          const SizedBox(height: 18),
                          Text('Stats', style: AppTextStyles.heading3()),
                          const SizedBox(height: 8),
                          GridView.count(
                            crossAxisCount: 3,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 0.95,
                            children: [
                              _statTile('Classes', _stats['totalClasses'],
                                  Icons.event_note_rounded),
                              _statTile('Sessions', _stats['sessionsTaken'],
                                  Icons.play_circle_outline_rounded),
                              _statTile('Students', _stats['totalStudents'],
                                  Icons.groups_rounded),
                              _statTile('Unique', _stats['uniqueStudents'],
                                  Icons.person_rounded),
                              _statTile('Upcoming', _stats['upcoming'],
                                  Icons.schedule_rounded),
                              _statTile('Recordings', _stats['recordings'],
                                  Icons.videocam_rounded),
                            ],
                          ),

                          const SizedBox(height: 18),
                          Text('Classes (${_classes.length})',
                              style: AppTextStyles.heading3()),
                          const SizedBox(height: 4),
                          if (_classes.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('No classes yet.',
                                  style: AppTextStyles.caption()),
                            )
                          else
                            ..._classes.map((c) =>
                                _classTile(Map<String, dynamic>.from(c as Map))),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _accent),
          const SizedBox(width: 10),
          Text('$label: ', style: AppTextStyles.caption()),
          Expanded(
            child: Text(value,
                style: AppTextStyles.body(), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
