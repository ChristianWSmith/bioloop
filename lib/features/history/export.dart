import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/database/database.dart';

String _csvEscape(String value) {
  if (value.contains(',') || value.contains('"') || value.contains('\n')) {
    return '"${value.replaceAll('"', '""')}"';
  }
  return value;
}

String exportFoodEntriesToCsv(List<FoodEntry> entries) {
  final buf = StringBuffer();
  buf.writeln('date,meal_type,name,servings,calories,protein_g,carbs_g,fat_g');
  for (final e in entries) {
    final date = e.loggedAt.substring(0, 10);
    buf.writeln(
      '${_csvEscape(date)},${_csvEscape(e.mealType)},'
      '${_csvEscape(e.name)},${e.servings},${e.calories.toInt()},'
      '${e.proteinGrams.toStringAsFixed(1)},${e.carbsGrams.toStringAsFixed(1)},'
      '${e.fatGrams.toStringAsFixed(1)}',
    );
  }
  return buf.toString();
}

String exportBodyweightToCsv(List<BodyweightEntry> entries) {
  final buf = StringBuffer();
  buf.writeln('date,weight_kg,unit');
  for (final e in entries) {
    final date = e.loggedAt.substring(0, 10);
    buf.writeln('${_csvEscape(date)},${e.weightKg},kg');
  }
  return buf.toString();
}

Future<void> shareCsv(String content, String filename) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    text: filename,
  );
}

Future<String> saveCsvToDownloads(String content, String filename) async {
  final dir = await getDownloadsDirectory()
      ?? await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}
