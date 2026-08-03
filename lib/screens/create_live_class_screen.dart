import 'package:flutter/material.dart';
import '../services/live_api.dart';
import 'live_broadcast_screen.dart';

/// Instructor creates a class: go live now, or schedule for later.
class CreateLiveClassScreen extends StatefulWidget {
  const CreateLiveClassScreen({super.key});

  @override
  State<CreateLiveClassScreen> createState() => _CreateLiveClassScreenState();
}

class _CreateLiveClassScreenState extends State<CreateLiveClassScreen> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  bool _goLiveNow = true;
  DateTime? _scheduledAt;
  bool _saving = false;

  static const _green = Color(0xFF6C63FF); // app accent (purple)

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(hours: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (t == null) return;
    setState(() {
      _scheduledAt = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }
    if (!_goLiveNow && _scheduledAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final c = await LiveApi.createClass(
        title: _title.text.trim(),
        description: _desc.text.trim(),
        goLiveNow: _goLiveNow,
        scheduledAt: _goLiveNow ? null : _scheduledAt,
      );
      if (!mounted) return;
      if (_goLiveNow) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LiveBroadcastScreen(liveClass: c),
          ),
        );
      } else {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Live Class'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Class title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _goLiveNow,
            activeColor: _green,
            title: const Text('Go live now'),
            subtitle: const Text('Turn off to schedule for later'),
            onChanged: (v) => setState(() => _goLiveNow = v),
          ),
          if (!_goLiveNow)
            ListTile(
              leading: const Icon(Icons.event, color: _green),
              title: Text(_scheduledAt == null
                  ? 'Pick date and time'
                  : _scheduledAt!.toLocal().toString().substring(0, 16)),
              trailing: const Icon(Icons.edit),
              onTap: _pickDateTime,
            ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
              ),
              onPressed: _saving ? null : _submit,
              icon: Icon(_goLiveNow ? Icons.sensors : Icons.schedule),
              label: Text(_saving
                  ? 'Please wait...'
                  : (_goLiveNow ? 'Create and go live' : 'Schedule class')),
            ),
          ),
        ],
      ),
    );
  }
}
