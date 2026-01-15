import 'package:attender_new/screens/home/widgets/manage_session_detail_page.dart';
import 'package:flutter/material.dart';

import '../../../services/class_service.dart';
import 'package:table_calendar/table_calendar.dart';

class ManageSessionsPage extends StatefulWidget {
  const ManageSessionsPage({super.key, required this.classService});

  final ClassService classService;

  @override
  State<ManageSessionsPage> createState() => _ManageSessionsPageState();
}

class _ManageSessionsPageState extends State<ManageSessionsPage> {
  bool _loading = true;
  String? _error;
  List<ClassSession> _sessions = [];
  Map<int, String> _classNames = {}; // classId -> name
  int? _selectedClassId; // null = all classes
  DateTime? _selectedDate;
  final DateTime _calendarStart = DateTime.now().subtract(
    const Duration(days: 1),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Widget _buildClassFilter(Color accentColor) {
    final items = <DropdownMenuItem<int?>>[];
    items.add(
      const DropdownMenuItem<int?>(value: null, child: Text('All classes')),
    );
    for (final e in _classNames.entries) {
      items.add(DropdownMenuItem<int?>(value: e.key, child: Text(e.value)));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<int?>(
              value: _selectedClassId,
              isExpanded: true,
              items: items,
              onChanged: (v) => setState(() => _selectedClassId = v),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedClassId = null),
            icon: const Icon(Icons.clear),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Color accentColor) {
    // Compute calendar bounds from session dates (respecting class filter).
    final List<DateTime> sessionDates = [];
    for (final s in _sessions) {
      if (_selectedClassId != null && s.classId != _selectedClassId) continue;
      final sd = s.sessionDate;
      if (sd == null || sd.isEmpty) continue;
      try {
        final p = DateTime.parse(sd);
        sessionDates.add(DateTime(p.year, p.month, p.day));
      } catch (_) {
        // ignore parse errors
      }
    }

    DateTime first;
    DateTime last;
    if (sessionDates.isNotEmpty) {
      sessionDates.sort((a, b) => a.compareTo(b));
      first = sessionDates.first;
      last = sessionDates.last;
    } else {
      first = _calendarStart;
      last = _calendarStart.add(const Duration(days: 29));
    }

    final initial = _selectedDate ?? first;
    // Clamp initial into bounds
    DateTime initialClamped = initial;
    if (initialClamped.isBefore(first)) initialClamped = first;
    if (initialClamped.isAfter(last)) initialClamped = last;

    // Build events map for TableCalendar: Date -> list of events (we store a 1 per session)
    final Map<DateTime, List<int>> events = {};
    for (final s in _sessions) {
      if (_selectedClassId != null && s.classId != _selectedClassId) continue;
      final key = s.sessionDate ?? '';
      if (key.isEmpty) continue;
      try {
        final p = DateTime.parse(key);
        final d = DateTime(p.year, p.month, p.day);
        events[d] = [...(events[d] ?? []), 1];
      } catch (_) {
        // ignore
      }
    }

    final selKey = _selectedDate != null
        ? DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
          )
        : null;
    final selCount = selKey != null ? (events[selKey]?.length ?? 0) : 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calendar',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          TableCalendar<int>(
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: accentColor.withOpacity(0.3),
                shape: BoxShape.rectangle,
              ),
              selectedDecoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.rectangle,
              ),
            ),
            firstDay: first,
            onFormatChanged: (format) => {},
            calendarFormat: CalendarFormat.month,
            lastDay: last,
            focusedDay: initialClamped,
            selectedDayPredicate: (d) =>
                _selectedDate != null &&
                d.year == _selectedDate!.year &&
                d.month == _selectedDate!.month &&
                d.day == _selectedDate!.day,
            eventLoader: (day) =>
                events[DateTime(day.year, day.month, day.day)] ?? [],
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDate = DateTime(
                  selectedDay.year,
                  selectedDay.month,
                  selectedDay.day,
                );
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, eventsList) {
                if (eventsList.isEmpty) return const SizedBox.shrink();
                return Positioned(
                  bottom: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${eventsList.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedDate == null
                    ? 'No date selected'
                    : '${_selectedDate!.day} ${_monthShort(_selectedDate!.month)} ${_selectedDate!.year}',
              ),
              Text(
                '$selCount session(s)',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final classes = await widget.classService.getTeacherClasses();
      _classNames = {for (var c in classes) c.id: c.name};
      final sessions = await widget.classService.fetchTeacherSessions();
      setState(() {
        _sessions = sessions;
        if (sessions.isNotEmpty) {
          final first = sessions.first.sessionDate;
          if (first != null) {
            final parsed = DateTime.parse(first);
            // Use a local date (year,month,day) to avoid timezone shifts.
            _selectedDate = DateTime(parsed.year, parsed.month, parsed.day);
          }
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = const Color(0xFF0E58BC);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manage your sessions',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text('Failed to load: check your connection.'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  _buildClassFilter(accentColor),
                  const SizedBox(height: 12),
                  _buildCalendarGrid(accentColor),
                  const SizedBox(height: 12),
                  _buildSessionList(accentColor),
                ],
              ),
      ),
    );
  }

  Widget _buildSessionList(Color accentColor) {
    final selectedKey = _selectedDate != null ? _dateKey(_selectedDate!) : null;
    final filtered = _sessions.where((s) {
      if (selectedKey != null && (s.sessionDate ?? '') != selectedKey) {
        return false;
      }
      if (_selectedClassId != null && s.classId != _selectedClassId) {
        return false;
      }
      return true;
    }).toList();

    if (filtered.isEmpty) {
      return Center(child: Text('No sessions on selected date.'));
    }

    return Expanded(
      child: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate((ctx, idx) {
              final s = filtered[idx];
              final className = _classNames[s.classId] ?? 'Class ${s.classId}';
              return FutureBuilder<int>(
                future: widget.classService.fetchSessionAttendanceCount(s.id),
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  return GestureDetector(
                    onTap: () {
                      // Open session detail page
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManageSessionDetailPage(
                            classService: widget.classService,
                            session: s,
                          ),
                        ),
                      ).then((_) => _load());
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.qr_code, color: accentColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${_prettyTime(s.startTime ?? '')} • ${s.sessionDate ?? ''}',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$count',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'attended',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }, childCount: filtered.length),
          ),
        ],
      ),
    );
  }

  String _monthShort(int m) {
    const names = [
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
    return names[(m - 1).clamp(0, 11)];
  }

  String _dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _prettyTime(String raw) {
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
