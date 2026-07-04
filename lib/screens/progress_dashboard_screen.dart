import 'package:flutter/material.dart';

class ProgressDashboardScreen extends StatelessWidget {
  const ProgressDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Progress Dashboard")),
      body: const Center(child: Text("Phase 1 Coming...")),
    );
  }
}
