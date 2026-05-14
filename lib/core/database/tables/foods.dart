import 'package:drift/drift.dart';

@TableIndex(name: 'idx_foods_name', columns: {#name})
class Foods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get servingLabel => text()();
  RealColumn get servingQuantity => real().withDefault(const Constant(1.0))();
  TextColumn get servingUnit => text().withDefault(const Constant('serving'))();
  RealColumn get caloriesPerServing => real()();
  RealColumn get proteinPerServing => real()();
  RealColumn get carbsPerServing => real()();
  RealColumn get fatPerServing => real()();
  TextColumn get barcode => text().nullable().unique()();
  TextColumn get source => text().withDefault(const Constant('manual'))();
  TextColumn get createdAt => text()();
}
