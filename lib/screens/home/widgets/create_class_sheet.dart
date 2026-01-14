import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/class_service.dart';
import 'class_icon_helper.dart';

Future<bool> showCreateClassSheet({
  required BuildContext context,
  required ClassService classService,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) {
      final padding = MediaQuery.of(ctx).viewInsets;
      return Padding(
        padding: EdgeInsets.only(bottom: padding.bottom),
        child: CreateClassSheet(classService: classService),
      );
    },
  );

  return result ?? false;
}

class CreateClassSheet extends StatefulWidget {
  const CreateClassSheet({super.key, required this.classService});

  final ClassService classService;

  @override
  State<CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends State<CreateClassSheet> {
  Map<String, IconData> get _iconOptions => kClassIcons;

  final _nameController = TextEditingController();
  final List<_ScheduleRow> _schedules = [_ScheduleRow(day: 'Monday')];
  String _selectedIcon = kDefaultClassIcon;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    for (final s in _schedules) {
      s.startCtrl.dispose();
      s.endCtrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Create Class',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              IconButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
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
              prefixIcon: Icon(_iconOptions[_selectedIcon], size: 20),
              filled: true,
              fillColor: Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            items: _iconOptions.entries
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
          ..._schedules.asMap().entries.map((entry) {
            final idx = entry.key;
            final sched = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: idx == 0 ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: sched.day,
                          items: days
                              .map(
                                (d) =>
                                    DropdownMenuItem(value: d, child: Text(d)),
                              )
                              .toList(),
                          onChanged: _saving
                              ? null
                              : (v) =>
                                    setState(() => sched.day = v ?? 'Monday'),
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
                      if (_schedules.length > 1)
                        IconButton(
                          onPressed: _saving
                              ? null
                              : () => setState(() => _schedules.removeAt(idx)),
                          icon: const Icon(Icons.delete_outline),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: sched.startCtrl,
                          readOnly: true,
                          onTap: _saving
                              ? null
                              : () async {
                                  await _pickTime(
                                    initial: sched.start,
                                    onPicked: (t) => setState(() {
                                      sched.start = t;
                                      sched.startCtrl.text = _pretty(t);
                                    }),
                                  );
                                },
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
                          controller: sched.endCtrl,
                          readOnly: true,
                          onTap: _saving
                              ? null
                              : () async {
                                  await _pickTime(
                                    initial: sched.end,
                                    onPicked: (t) => setState(() {
                                      sched.end = t;
                                      sched.endCtrl.text = _pretty(t);
                                    }),
                                  );
                                },
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
                      () => _schedules.add(_ScheduleRow(day: 'Monday')),
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
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_validate()) return;
    setState(() => _saving = true);
    try {
      final payload = _schedules
          .map(
            (s) => SchedulePayload(
              day: s.day,
              start: _formatTime(s.start!),
              end: _formatTime(s.end!),
            ),
          )
          .toList();

      await widget.classService.createClassWithSchedules(
        name: _nameController.text.trim(),
        icon: _selectedIcon,
        schedules: payload,
      );

      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (e) {
      _showSnack(e.message);
    } on StateError catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Failed to create class');
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
    if (_schedules.isEmpty) {
      _showSnack('Add at least one schedule');
      return false;
    }
    for (final s in _schedules) {
      if (s.start == null || s.end == null) {
        _showSnack('Please pick start and end times for all schedules');
        return false;
      }
      final startMinutes = s.start!.hour * 60 + s.start!.minute;
      final endMinutes = s.end!.hour * 60 + s.end!.minute;
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

  String _formatTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _pretty(TimeOfDay time) {
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
  _ScheduleRow({required this.day})
    : startCtrl = TextEditingController(),
      endCtrl = TextEditingController();

  String day;
  TimeOfDay? start;
  TimeOfDay? end;
  final TextEditingController startCtrl;
  final TextEditingController endCtrl;
}
