import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../services/class_service.dart';

class ManageSessionDetailPage extends StatefulWidget {
  const ManageSessionDetailPage({
    super.key,
    required this.classService,
    required this.session,
  });

  final ClassService classService;
  final ClassSession session;

  @override
  State<ManageSessionDetailPage> createState() =>
      _ManageSessionDetailPageState();
}

class _ManageSessionDetailPageState extends State<ManageSessionDetailPage> {
  bool _loading = true;
  String? _error;
  List<StudentRecord> _attendees = [];

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
      final a = await widget.classService.fetchSessionAttendances(
        widget.session.id,
      );
      setState(() {
        _attendees = a;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete session'),
        content: const Text('Delete this session and all attendance records?'),
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
    await widget.classService.deleteSession(widget.session.id);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _closeSession() async {
    try {
      await widget.classService.closeActiveSession(widget.session.classId);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to close: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF0E58BC);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Failed: $_error'))
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.wifi_tethering, color: accentColor),
                              const SizedBox(width: 8),
                              const Text(
                                'Session',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: QrImageView(
                                data: widget.session.attendanceCode,
                                size: 160,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: accentColor,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Started at ${widget.session.startTime ?? ''}${widget.session.sessionDate != null ? ' • ${widget.session.sessionDate}' : ''}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              if (widget.session.isActive)
                                TextButton(
                                  onPressed: _closeSession,
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Close Session',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: _confirmDelete,
                                style: TextButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Attended students',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _attendees.isEmpty
                          ? const Center(child: Text('No attendees yet'))
                          : ListView.separated(
                              itemCount: _attendees.length,
                              separatorBuilder: (_, _) => const Divider(),
                              itemBuilder: (ctx, idx) {
                                final s = _attendees[idx];
                                return ListTile(
                                  title: Text(s.name),
                                  subtitle: Text(s.email ?? ''),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
