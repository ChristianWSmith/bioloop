import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'database_provider.dart';
import 'reset_provider.dart';

final goalsProvider = Provider<GoalsService>((ref) {
  final db = ref.watch(databaseProvider);
  return GoalsService(db);
});

final userGoalsProvider = FutureProvider<UserGoal?>((ref) async {
  ref.watch(resetTriggerProvider);
  return ref.read(goalsProvider).getGoals();
});

class GoalsService {
  final AppDatabase db;
  GoalsService(this.db);

  Future<UserGoal?> getGoals() => db.getGoals();

  Future<void> upsertGoals(UserGoalsCompanion goals) => db.upsertGoals(goals);
}
