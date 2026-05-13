import 'package:drift/drift.dart';

class MealTemplates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get foods => text()();
  TextColumn get createdAt => text()();
}
