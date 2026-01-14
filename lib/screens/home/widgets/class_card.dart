import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import 'class_icon_helper.dart';
import 'class_detail_page.dart';
import 'edit_class_sheet.dart';

class ClassCard extends StatefulWidget {
  const ClassCard({
    super.key,
    required this.classService,
    required this.classRecord,
    this.onChanged,
  });

  final ClassService classService;
  final ClassRecord classRecord;
  final VoidCallback? onChanged; // refresh callback after edit/delete

  @override
  State<ClassCard> createState() => _ClassCardState();
}

class _ClassCardState extends State<ClassCard> {
  bool _loadingSched = true;
  String? _errorSched;
  List<ScheduleRecord> _schedules = const [];
  bool _deleting = false;

  static const _dayOrder = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() {
      _loadingSched = true;
      _errorSched = null;
    });
    try {
      final rows = await widget.classService.fetchClassSchedules(
        widget.classRecord.id,
      );
      if (!mounted) return;
      setState(() => _schedules = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorSched = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSched = false);
    }
  }

  String _daysSummary() {
    if (_schedules.isEmpty) return 'No schedules';
    final daysSet = {for (final d in _schedules.map((s) => s.day)) d};
    if (daysSet.length == 7) return 'Daily';
    final ordered = _dayOrder.where(daysSet.contains).toList();
    final abbr = ordered.map((d) => d.substring(0, 3)).join(', ');
    return abbr;
  }

  String _studentCountLabel() {
    final count = widget.classRecord.studentCount;
    if (count == null) return 'Students';
    if (count == 0) return 'No students';
    if (count == 1) return '1 student';
    return '$count students';
  }

  Future<void> _openDetail() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClassDetailPage(
          classService: widget.classService,
          classId: widget.classRecord.id,
          className: widget.classRecord.name,
          classIcon: widget.classRecord.icon,
          teacherId: widget.classRecord.teacherId,
        ),
      ),
    );
    await _loadSchedules();
    widget.onChanged?.call();
  }

  Future<void> _editClass() async {
    final result = await showEditClassSheet(
      context: context,
      classService: widget.classService,
      classId: widget.classRecord.id,
      initialName: widget.classRecord.name,
      initialIcon: widget.classRecord.icon ?? kDefaultClassIcon,
      schedules: _schedules,
    );
    if (result != null) {
      // Update local display
      setState(() {
        widget.classRecord.name = result.name;
        widget.classRecord.icon = result.icon;
      });
      await widget.classService.updateCachedClass(
        ClassRecord(
          id: widget.classRecord.id,
          name: widget.classRecord.name,
          icon: widget.classRecord.icon,
          teacherId: widget.classRecord.teacherId,
        ),
      );
      await _loadSchedules();
      widget.onChanged?.call();
    }
  }

  Future<void> _confirmDelete() async {
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete class?'),
        content: const Text('This will remove the class and its schedules.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (conf == true) {
      await _deleteClass();
    }
  }

  Future<void> _deleteClass() async {
    setState(() => _deleting = true);
    try {
      await widget.classService.deleteClass(widget.classRecord.id);
      await widget.classService.removeCachedClass(widget.classRecord.id);
      if (!mounted) return;
      widget.onChanged?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF0E58BC);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
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
                      widget.classRecord.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: accent.withOpacity(0.12),
                          child: Icon(
                            classIconFor(widget.classRecord.icon),
                            color: accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.group_outlined,
                          size: 16,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _studentCountLabel(),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        if (_loadingSched)
                          const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.black54),
                          )
                        else if (_errorSched != null)
                          const Text(
                            '—',
                            style: TextStyle(color: Colors.black54),
                          )
                        else
                          Row(
                            children: [
                              Icon(
                                Icons.event_available_outlined,
                                size: 16,
                                color: Colors.black54,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _daysSummary(),
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) async {
                  switch (value) {
                    case 'view':
                      await _openDetail();
                      break;
                    case 'edit':
                      await _editClass();
                      break;
                    case 'delete':
                      await _confirmDelete();
                      break;
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'view', child: Text('View Class')),
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openDetail,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade300),
                backgroundColor: accent.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: !_deleting
                  ? const Text('View Class')
                  : const Text('Deleting Class'),
            ),
          ),
        ],
      ),
    );
  }
}
