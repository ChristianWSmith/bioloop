import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'database_provider.dart';
import 'reset_provider.dart';

class BodyweightService {
  final AppDatabase db;
  BodyweightService({required this.db});

  Future<int> insertWeight(BodyweightEntriesCompanion entry) =>
      db.insertWeight(entry);

  Future<void> updateWeight(BodyweightEntry entry) => db.updateWeight(entry);

  Future<int> deleteWeight(int id) => db.deleteWeight(id);

  Future<List<BodyweightEntry>> getWeights({int? limit, DateTime? since}) =>
      db.getWeights(limit: limit, since: since);
}

final bodyweightServiceProvider = Provider<BodyweightService>((ref) {
  return BodyweightService(db: ref.read(databaseProvider));
});

final bodyweightProvider = FutureProvider<List<BodyweightEntry>>((ref) async {
  ref.watch(resetTriggerProvider);
  return ref.read(bodyweightServiceProvider).getWeights();
});
