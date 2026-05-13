import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database.dart';
import '../../../providers/database_provider.dart';

class TemplateFood {
  final String name;
  final double calories;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double servings;
  final String servingLabel;

  const TemplateFood({
    required this.name,
    required this.calories,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.servings,
    required this.servingLabel,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'calories': calories,
        'protein_grams': proteinGrams,
        'carbs_grams': carbsGrams,
        'fat_grams': fatGrams,
        'servings': servings,
        'serving_label': servingLabel,
      };

  factory TemplateFood.fromJson(Map<String, dynamic> json) => TemplateFood(
        name: json['name'] as String,
        calories: (json['calories'] as num).toDouble(),
        proteinGrams: (json['protein_grams'] as num).toDouble(),
        carbsGrams: (json['carbs_grams'] as num).toDouble(),
        fatGrams: (json['fat_grams'] as num).toDouble(),
        servings: (json['servings'] as num).toDouble(),
        servingLabel: json['serving_label'] as String,
      );
}

class MealTemplatesSheet extends ConsumerWidget {
  const MealTemplatesSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Meal Templates',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: FutureBuilder<List<MealTemplate>>(
                  future: db.getAllTemplates(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final templates = snapshot.data ?? [];
                    if (templates.isEmpty) {
                      return const Center(child: Text('No templates yet'));
                    }
                    return ListView.builder(
                      controller: scrollController,
                      itemCount: templates.length,
                      itemBuilder: (context, i) {
                        final t = templates[i];
                        final foods =
                            _parseTemplateFoods(t.foods);
                        return ListTile(
                          title: Text(t.name),
                          subtitle: Text(
                            '${foods.length} food${foods.length == 1 ? '' : 's'}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () =>
                                    Navigator.of(context).pop(foods),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add'),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: Icon(Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete template?'),
                                      content:
                                          Text('Delete "${t.name}"?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx).pop(true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    await db.deleteTemplate(t.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Deleted "${t.name}"'),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

List<TemplateFood> _parseTemplateFoods(String json) {
  final list = jsonDecode(json) as List<dynamic>;
  return list
      .map((e) => TemplateFood.fromJson(e as Map<String, dynamic>))
      .toList();
}

String encodeTemplateFoods(List<TemplateFood> foods) {
  return jsonEncode(foods.map((f) => f.toJson()).toList());
}

Future<void> saveCurrentFoodsAsTemplate(
  BuildContext context,
  AppDatabase db,
  FoodEntry Function(int index) getEntry,
  int entryCount,
) async {
  final nameController = TextEditingController();
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Save as template'),
      content: TextField(
        controller: nameController,
        autofocus: true,
        decoration: const InputDecoration(
          hintText: 'Template name',
          labelText: 'Name',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = nameController.text.trim();
            if (text.isNotEmpty) {
              Navigator.of(ctx).pop(text);
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (name == null) return;

  final foods = <TemplateFood>[];
  for (var i = 0; i < entryCount; i++) {
    final e = getEntry(i);
    foods.add(TemplateFood(
      name: e.name,
      calories: e.calories,
      proteinGrams: e.proteinGrams,
      carbsGrams: e.carbsGrams,
      fatGrams: e.fatGrams,
      servings: e.servings,
      servingLabel: e.servingLabel,
    ));
  }

  await db.insertTemplate(MealTemplatesCompanion.insert(
    name: name,
    foods: encodeTemplateFoods(foods),
    createdAt: DateTime.now().toIso8601String(),
  ));
}
