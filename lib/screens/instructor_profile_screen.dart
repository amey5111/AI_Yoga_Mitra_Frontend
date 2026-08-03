import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/live_api.dart';

/// Instructor edits their public profile: photo, specialty, bio.
class InstructorProfileScreen extends StatefulWidget {
  const InstructorProfileScreen({super.key});

  @override
  State<InstructorProfileScreen> createState() =>
      _InstructorProfileScreenState();
}

class _InstructorProfileScreenState extends State<InstructorProfileScreen> {
  static const _accent = Color(0xFF6C63FF);
  final _bio = TextEditingController();
  final _specialty = TextEditingController();
  String _photo = '';
  String _name = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final uid = p.getString('userId') ?? '';
    _name = p.getString('name') ?? 'Instructor';
    try {
      final prof = await LiveApi.getProfile(uid);
      _bio.text = (prof['bio'] ?? '').toString();
      _specialty.text = (prof['specialty'] ?? '').toString();
      _photo = (prof['photo'] ?? '').toString();
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) return;
    setState(() => _photo = base64Encode(bytes));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await LiveApi.saveProfile(
        bio: _bio.text.trim(),
        specialty: _specialty.text.trim(),
        photo: _photo,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile saved')));
      Navigator.pop(context, true);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _bio.dispose();
    _specialty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: _accent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFEDE9FF),
                      backgroundImage: _photo.isNotEmpty
                          ? MemoryImage(base64Decode(_photo))
                          : null,
                      child: _photo.isEmpty
                          ? const Icon(Icons.add_a_photo,
                              color: _accent, size: 28)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text('Tap photo to change',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(_name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _specialty,
                  decoration: const InputDecoration(
                    labelText: 'Specialty (e.g. Hatha, Vinyasa)',
                    prefixIcon: Icon(Icons.self_improvement),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bio,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white),
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save profile'),
                  ),
                ),
              ],
            ),
    );
  }
}
