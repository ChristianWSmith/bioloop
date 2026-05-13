import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/database/database.dart';
import 'database_provider.dart';

final onboardingProvider = Provider<OnboardingService>((ref) {
  final db = ref.watch(databaseProvider);
  return OnboardingService(db);
});

class OnboardingService {
  final AppDatabase db;
  OnboardingService(this.db);

  Future<UserGoal?> getGoals() => db.getGoals();

  Future<void> completeOnboarding(UserGoalsCompanion goals) =>
      db.upsertGoals(goals);

  Future<int> saveStartingWeight(BodyweightEntriesCompanion entry) =>
      db.insertWeight(entry);
}
