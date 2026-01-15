import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import 'manage_session_detail_page.dart';

class ManageClassSessionsPage extends StatefulWidget {
  const ManageClassSessionsPage({
    super.key,
    required this.classService,
    required this.classId,
    required this.className,
  });

  final ClassService classService;
  final int classId;
  final String className;

  @override
  State<ManageClassSessionsPage> createState() =>
      _ManageClassSessionsPageState();
}

class _ManageClassSessionsPageState extends State<ManageClassSessionsPage> {
  bool _loading = true;
  String? _error;
  List<ClassSession> _sessions = [];

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
      final s = await widget.classService.fetchSessionsForClass(widget.classId);
      setState(() {
        _sessions = s;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete(ClassSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text('Delete this session? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.classService.deleteSession(s.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.className),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Failed: $_error'))
          : _sessions.isEmpty
          ? Center(child: Text('No sessions found.'))
          : Padding(
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                itemCount: _sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final s = _sessions[idx];
                  return ListTile(
                    title: Text('Session ${s.sessionDate ?? ''}'),
                    subtitle: Text(
                      '${s.startTime ?? ''} • ${s.isActive ? 'Active' : 'Closed'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.manage_search,
                            color: Colors.black87,
                          ),
                          tooltip: 'Manage',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManageSessionDetailPage(
                                classService: widget.classService,
                                session: s,
                              ),
                            ),
                          ).then((_) => _load()),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.redAccent,
                          ),
                          onPressed: () => _confirmDelete(s),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageSessionDetailPage(
                          classService: widget.classService,
                          session: s,
                        ),
                      ),
                    ).then((_) => _load()),
                  );
                },
              ),
            ),
    );
  }
}
