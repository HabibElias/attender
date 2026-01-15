import 'package:hive_flutter/hive_flutter.dart';

class DataCacheStore {
  const DataCacheStore();

  static const String boxName = 'dataCache';

  Future<Box> _openBox() => Hive.openBox(boxName);

  Future<List<T>?> readList<T>({
    required String key,
    required T Function(Map<String, dynamic> map) fromMap,
  }) async {
    final box = await _openBox();
    final cached = box.get(key);
    if (cached is! List) return null;

    try {
      return cached
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map(fromMap)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> writeList({
    required String key,
    required List<Map<String, dynamic>> value,
  }) async {
    final box = await _openBox();
    await box.put(key, value);
  }

  Future<void> updateListItem<T>({
    required String key,
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    required bool Function(T value) matches,
    required T updated,
  }) async {
    final list = await readList<T>(key: key, fromMap: fromMap);
    if (list == null) return;

    final idx = list.indexWhere(matches);
    if (idx == -1) return;

    final copy = [...list];
    copy[idx] = updated;
    await writeList(key: key, value: copy.map(toMap).toList());
  }

  Future<void> removeListItem<T>({
    required String key,
    required T Function(Map<String, dynamic> map) fromMap,
    required Map<String, dynamic> Function(T value) toMap,
    required bool Function(T value) shouldKeep,
  }) async {
    final list = await readList<T>(key: key, fromMap: fromMap);
    if (list == null) return;

    final filtered = list.where(shouldKeep).toList();
    await writeList(key: key, value: filtered.map(toMap).toList());
  }
}
