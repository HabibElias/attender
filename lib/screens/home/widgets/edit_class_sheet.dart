import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import 'class_icon_helper.dart';

class EditClassResult {
  const EditClassResult({required this.name, required this.icon});

  final String name;
  final String icon;
}

Future<EditClassResult?> showEditClassSheet({
  required BuildContext context,
  required ClassService classService,
  required int classId,
  required String initialName,
  required String initialIcon,
  required List<ScheduleRecord> schedules,
}) async {
  final result = await showModalBottomSheet<EditClassResult>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      final padding = MediaQuery.of(ctx).viewInsets;
      return Padding(
        padding: EdgeInsets.only(bottom: padding.bottom),
        child: EditClassSheet(
          classService: classService,
          classId: classId,
          initialName: initialName,
          initialIcon: initialIcon,
          schedules: schedules,
        ),
      );
    },
  );

  return result;
}

class EditClassSheet extends StatefulWidget {
  const EditClassSheet({
    super.key,
    required this.classService,
    required this.classId,
    required this.initialName,
    required this.initialIcon,
    required this.schedules,
  });

  final ClassService classService;
  final int classId;
  final String initialName;
  final String initialIcon;
  final List<ScheduleRecord> schedules;

  @override
  State<EditClassSheet> createState() => _EditClassSheetState();
}

class _EditClassSheetState extends State<EditClassSheet> {
  final _nameController = TextEditingController();
  final List<_ScheduleRow> _rows = [];
  late String _selectedIcon;
  bool _saving = false;

  static const _days = [
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
    _nameController.text = widget.initialName;
    _selectedIcon = widget.initialIcon.isEmpty
        ? kDefaultClassIcon
        : widget.initialIcon;
    _rows.addAll(
      widget.schedules.isEmpty
          ? [_ScheduleRow(day: _days.first)]
          : widget.schedules
                .map(
                  (s) => _ScheduleRow(
                    day: s.day,
                    start: _fromHm(s.start),
                    end: _fromHm(s.end),
                  ),
                )
                .toList(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit Class',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Class Name',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !_saving,
              decoration: InputDecoration(
                hintText: 'e.g., Mobile Computing',
                prefixIcon: const Icon(Icons.school_outlined),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Class Icon',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedIcon,
              decoration: InputDecoration(
                hintText: 'Select icon',
                prefixIcon: Icon(classIconFor(_selectedIcon), size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items: kClassIcons.entries
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Row(
                        children: [
                          Icon(e.value, size: 20),
                          const SizedBox(width: 8),
                          Text(e.key.replaceAll('_', ' ')),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _selectedIcon = v ?? _selectedIcon),
            ),
            const SizedBox(height: 12),
            ..._rows.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return Padding(
                padding: EdgeInsets.only(top: idx == 0 ? 0 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: row.day,
                            items: _days
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (v) => setState(
                                    () => row.day = v ?? _days.first,
                                  ),
                            decoration: InputDecoration(
                              hintText: 'Day of week',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        if (_rows.length > 1)
                          IconButton(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _rows.removeAt(idx)),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: row.startCtrl,
                            readOnly: true,
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                    initial: row.start,
                                    onPicked: (t) {
                                      setState(() {
                                        row.start = t;
                                        row.startCtrl.text = _pretty(t);
                                      });
                                    },
                                  ),
                            decoration: InputDecoration(
                              hintText: 'Start time',
                              prefixIcon: const Icon(Icons.schedule),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: row.endCtrl,
                            readOnly: true,
                            onTap: _saving
                                ? null
                                : () => _pickTime(
                                    initial: row.end,
                                    onPicked: (t) {
                                      setState(() {
                                        row.end = t;
                                        row.endCtrl.text = _pretty(t);
                                      });
                                    },
                                  ),
                            decoration: InputDecoration(
                              hintText: 'End time',
                              prefixIcon: const Icon(Icons.schedule_outlined),
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => setState(
                        () => _rows.add(_ScheduleRow(day: _days.first)),
                      ),
                icon: const Icon(Icons.add),
                label: const Text('Add schedule'),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0E58BC),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final payload = _rows
          .map(
            (r) => SchedulePayload(
              day: r.day,
              start: _toHm(r.start!),
              end: _toHm(r.end!),
            ),
          )
          .toList();

      await widget.classService.updateClassWithSchedules(
        classId: widget.classId,
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        schedules: payload,
      );

      if (mounted) {
        Navigator.pop(
          context,
          EditClassResult(
            name: _nameController.text.trim(),
            icon: _selectedIcon,
          ),
        );
      }
    } catch (e) {
      _showSnack('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  bool _validate() {
    if (_nameController.text.trim().isEmpty) {
      _showSnack('Please enter a class name');
      return false;
    }
    if (_selectedIcon.isEmpty) {
      _showSnack('Please pick an icon');
      return false;
    }
    if (_rows.isEmpty) {
      _showSnack('Add at least one schedule');
      return false;
    }
    for (final r in _rows) {
      if (r.start == null || r.end == null) {
        _showSnack('Please pick start and end times for all schedules');
        return false;
      }
      final start = r.start!;
      final end = r.end!;
      final startMinutes = start.hour * 60 + start.minute;
      final endMinutes = end.hour * 60 + end.minute;
      if (endMinutes <= startMinutes) {
        _showSnack('End time must be after start time');
        return false;
      }
    }
    return true;
  }

  Future<void> _pickTime({
    required TimeOfDay? initial,
    required void Function(TimeOfDay) onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) onPicked(picked);
  }

  TimeOfDay? _fromHm(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _toHm(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _pretty(TimeOfDay? time) {
    if (time == null) return 'Pick time';
    final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour12:${time.minute.toString().padLeft(2, '0')} $suffix';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ScheduleRow {
  _ScheduleRow({required this.day, this.start, this.end})
    : startCtrl = TextEditingController(
        text: start == null ? '' : _initialPretty(start),
      ),
      endCtrl = TextEditingController(
        text: end == null ? '' : _initialPretty(end),
      );

  String day;
  TimeOfDay? start;
  TimeOfDay? end;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;

  void dispose() {
    startCtrl.dispose();
    endCtrl.dispose();
  }
}

String _initialPretty(TimeOfDay time) {
  final hour12 = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '$hour12:${time.minute.toString().padLeft(2, '0')} $suffix';
}
