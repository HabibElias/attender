import 'package:flutter/material.dart';
import '../../../services/class_service.dart';

Future<bool> showAddStudentsSheet({
  required BuildContext context,
  required ClassService classService,
  required int classId,
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
        child: AddStudentsSheet(classService: classService, classId: classId),
      );
    },
  );

  return result ?? false;
}

class AddStudentsSheet extends StatefulWidget {
  const AddStudentsSheet({
    super.key,
    required this.classService,
    required this.classId,
  });

  final ClassService classService;
  final int classId;

  @override
  State<AddStudentsSheet> createState() => _AddStudentsSheetState();
}

class _AddStudentsSheetState extends State<AddStudentsSheet> {
  final _searchCtrl = TextEditingController();
  bool _searching = false;
  String? _error;
  List<StudentRecord> _results = [];
  String? _addingStudentId;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final rows = await widget.classService.searchStudents(q);
      if (!mounted) return;
      setState(() => _results = rows);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _add(String studentId) async {
    setState(() => _addingStudentId = studentId);
    try {
      await widget.classService.addStudentToClass(
        params: AddStudentToClassParams(
          classId: widget.classId,
          studentId: studentId,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student added successfully')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add: $e')));
    } finally {
      if (mounted) setState(() => _addingStudentId = null);
    }
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
                  'Add Students',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Search by name or email',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchCtrl,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'e.g., Jane Doe or jane@school.edu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () => _search(_searchCtrl.text),
                      ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            if (_results.isEmpty && !_searching)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E58BC).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Text(
                  'No students yet. Try searching above.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final s = _results[index];
                  final adding = _addingStudentId == s.id;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    title: Text(s.name),
                    subtitle: s.email == null || s.email!.isEmpty
                        ? null
                        : Text(s.email!),
                    trailing: adding
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : ElevatedButton.icon(
                            onPressed: () => _add(s.id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E58BC),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('Add'),
                          ),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Backwards-compatible page wrapper (not used by new flow)
class AddStudentsPage extends StatelessWidget {
  const AddStudentsPage({
    super.key,
    required this.classId,
    required this.classService,
  });

  final int classId;
  final ClassService classService;

  @override
  Widget build(BuildContext context) {
    // Fallback full-screen that embeds the sheet content for consistency
    return Scaffold(
      appBar: AppBar(title: const Text('Add Students')),
      body: SafeArea(
        child: AddStudentsSheet(classService: classService, classId: classId),
      ),
    );
  }
}
