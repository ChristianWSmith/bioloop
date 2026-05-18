import 'package:drift/drift.dart';

class UserGoals extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get goalType => text()();
  RealColumn get calorieAdjustment => real().nullable()();
  RealColumn get proteinGPerLb => real().withDefault(const Constant(1.0))();
  RealColumn get fatCaloriePct => real().withDefault(const Constant(25.0))();
  TextColumn get sex => text().nullable()();
  RealColumn get heightCm => real().nullable()();
  TextColumn get birthdate => text().nullable()();
  IntColumn get age => integer().nullable()();
  IntColumn get useImperial => integer().withDefault(const Constant(0))();
  IntColumn get activityLevel => integer().withDefault(const Constant(3))();
  IntColumn get onboardingCompleted => integer().withDefault(const Constant(0))();
  IntColumn get accentColorSeed => integer().nullable()();
  TextColumn get proteinBasis => text().withDefault(const Constant('bodyweight'))();
  TextColumn get updatedAt => text()();
}
