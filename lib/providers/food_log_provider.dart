import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'database_provider.dart';
import 'reset_provider.dart';

class FoodLogService {
  final AppDatabase db;
  FoodLogService({required this.db});

  Future<int> insertEntry(FoodEntriesCompanion entry) => db.insertEntry(entry);

  Future<List<FoodEntry>> getEntriesForDate(DateTime date) =>
      db.getEntriesForDate(date);

  Future<int> deleteEntry(int id) => db.deleteEntry(id);

  Future<List<FoodEntry>> getEntriesPaginated({int offset = 0, int limit = 20}) =>
      db.getEntriesPaginated(offset: offset, limit: limit);

  Future<void> updateEntry(FoodEntry entry) => db.updateEntry(entry);
}

final foodLogProvider = Provider<FoodLogService>((ref) {
  return FoodLogService(db: ref.read(databaseProvider));
});

final todaysFoodProvider = FutureProvider<List<FoodEntry>>((ref) async {
  ref.watch(resetTriggerProvider);
  final logService = ref.read(foodLogProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return await logService.getEntriesForDate(today);
});
