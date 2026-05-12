import 'package:drift/drift.dart';

class Recipes extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  RealColumn get servingSize => real()();
  TextColumn get servingLabel => text()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
}
