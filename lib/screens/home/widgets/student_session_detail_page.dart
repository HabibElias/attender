import 'package:flutter/material.dart';

import '../../../services/class_service.dart';

class StudentSessionDetailPage extends StatefulWidget {
  const StudentSessionDetailPage({
    super.key,
    required this.classService,
    required this.session,
    required this.initiallyAttended,
  });

  final ClassService classService;
  final ClassSession session;
  final bool initiallyAttended;

  @override
  State<StudentSessionDetailPage> createState() =>
      _StudentSessionDetailPageState();
}

class _StudentSessionDetailPageState extends State<StudentSessionDetailPage> {
  bool _loading = true;
  String? _error;
  bool _attended = false;

  @override
  void initState() {
    super.initState();
    _attended = widget.initiallyAttended;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final attended = await widget.classService.fetchAttendedSessionIds([
        widget.session.id,
      ]);
      if (!mounted) return;
      setState(() {
        _attended = attended.contains(widget.session.id);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) {
        // ignore: control_flow_in_finally
        return;
      }
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accentColor = Color(0xFF0E58BC);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Session details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
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
                              Icon(Icons.history, color: accentColor),
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
                          _StatusRow(attended: _attended),
                          const SizedBox(height: 12),
                          Text(
                            'Date: ${_prettyDate(widget.session.sessionDate)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Time: ${_prettyRange(widget.session.startTime, widget.session.endTime)}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'State: ${widget.session.isActive ? 'Active' : 'Closed'}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Your attendance',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        _attended
                            ? 'You attended this session.'
                            : 'No attendance record found for you.',
                        style: TextStyle(
                          color: _attended
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  static String _prettyDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  static String _prettyRange(String? start, String? end) {
    final s = start == null || start.isEmpty ? null : _prettyTime(start);
    final e = end == null || end.isEmpty ? null : _prettyTime(end);
    if (s == null && e == null) return 'Unavailable';
    if (s != null && e != null) return '$s - $e';
    if (s != null) return 'Started at $s';
    return 'Ended at $e';
  }

  static String _prettyTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final suffix = hour >= 12 ? 'PM' : 'AM';
    final minuteStr = minute.toString().padLeft(2, '0');
    return '$hour12:$minuteStr $suffix';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.attended});

  final bool attended;

  @override
  Widget build(BuildContext context) {
    final chipBg = attended
        ? Colors.green.withOpacity(0.12)
        : Colors.red.withOpacity(0.12);
    final chipFg = attended ? Colors.green.shade800 : Colors.red.shade800;

    return Row(
      children: [
        Expanded(
          child: Text(
            attended ? 'Attended' : 'Missed',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Icon(
                attended ? Icons.check_circle : Icons.cancel,
                size: 18,
                color: chipFg,
              ),
              const SizedBox(width: 6),
              Text(
                attended ? 'Attended' : 'Missed',
                style: TextStyle(
                  color: chipFg,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
