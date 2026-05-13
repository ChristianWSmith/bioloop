import 'package:drift/drift.dart';

class BodyweightEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  RealColumn get weightKg => real()();
  TextColumn get loggedAt => text()();
}
