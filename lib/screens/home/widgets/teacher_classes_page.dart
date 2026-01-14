import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import 'class_card.dart';

class TeacherClassesPage extends StatefulWidget {
  const TeacherClassesPage({super.key, required this.classService});

  final ClassService classService;

  @override
  State<TeacherClassesPage> createState() => _TeacherClassesPageState();
}

class _TeacherClassesPageState extends State<TeacherClassesPage> {
  bool _loading = true;
  String? _error;
  List<ClassRecord> _classes = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await widget.classService.getTeacherClasses(
        forceRefresh: false,
      );
      if (!mounted) return;
      setState(() => _classes = classes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> refresh() async {
    try {
      final classes = await widget.classService.getTeacherClasses(
        forceRefresh: true,
      );
      if (!mounted) return;
      setState(() => _classes = classes);
    } catch (e) {
      // keep existing list on error
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 32, color: Colors.red),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_classes.isEmpty) {
      return RefreshIndicator(
        onRefresh: refresh,
        displacement: 120,
        color: Theme.of(context).colorScheme.onPrimary,
        backgroundColor: Theme.of(context).colorScheme.primary,
        strokeWidth: 3.0,
        semanticsLabel: 'Pull to refresh',
        child: Center(
          child: Semantics(
            label:
                'No classes available. Use the add button to create your first class.',
            child: Text('No classes yet. Tap + to create one.'),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your Classes',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 4),
              Text(
                'Manage your active classes',
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._classes.map(
            (c) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClassCard(
                classService: widget.classService,
                classRecord: c,
                onChanged: () {
                  // trigger refresh after edit/delete
                  refresh();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
