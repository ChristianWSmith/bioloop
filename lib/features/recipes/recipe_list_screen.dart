import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/database.dart';
import '../../providers/data_trigger_provider.dart';
import '../../providers/database_provider.dart';
import '../../providers/food_log_provider.dart';
import '../../providers/recipe_provider.dart';
import 'recipe_form_screen.dart';
import 'widgets/log_recipe_sheet.dart';

class RecipeListScreen extends ConsumerWidget {
  final bool pickerMode;

  const RecipeListScreen({super.key, this.pickerMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync = ref.watch(recipeListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipes'),
        actions: [
          if (!pickerMode)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const RecipeFormScreen(),
                  ),
                );
                if (result == true) {
                  ref.invalidate(recipeListProvider);
                }
              },
              tooltip: 'New recipe',
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'recipe_add',
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => const RecipeFormScreen(),
            ),
          );
          if (result == true) {
            ref.invalidate(recipeListProvider);
          }
        },
        tooltip: 'New recipe',
        child: const Icon(Icons.add),
      ),
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (recipes) {
          if (recipes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book, size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    'No recipes yet.\nTap + to create one.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final recipe = recipes[index];
              return _RecipeCard(
                recipe: recipe,
                pickerMode: pickerMode,
                onTap: () => _openRecipe(context, ref, recipe),
                onDelete: () => _deleteRecipe(context, ref, recipe),
                onDuplicate: () => _duplicateRecipe(context, ref, recipe),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openRecipe(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    if (pickerMode) {
      final detail = await ref.read(recipeDetailProvider(recipe.id).future);
      if (detail == null || !context.mounted) return;
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => LogRecipeSheet(detail: detail),
      );
      if (result == true && context.mounted) {
        ref.invalidate(todaysFoodProvider);
        ref.read(dataTriggerProvider.notifier).state++;
        Navigator.of(context).pop(true);
      }
    } else {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => RecipeFormScreen(recipeId: recipe.id),
        ),
      );
      if (result == true && context.mounted) {
        ref.invalidate(recipeListProvider);
      }
    }
  }

  Future<void> _deleteRecipe(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Delete "${recipe.name}" and all its ingredients?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = ref.read(databaseProvider);
      await db.deleteRecipe(recipe.id);
      ref.invalidate(recipeListProvider);
    }
  }

  Future<void> _duplicateRecipe(
      BuildContext context, WidgetRef ref, Recipe recipe) async {
    final db = ref.read(databaseProvider);
    final newRecipe = await db.duplicateRecipe(recipe.id);
    ref.invalidate(recipeListProvider);
    if (!context.mounted) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RecipeFormScreen(recipeId: newRecipe.id),
      ),
    );
    if (result == true && context.mounted) {
      ref.invalidate(recipeListProvider);
    }
  }
}

class _RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final bool pickerMode;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;

  const _RecipeCard({
    required this.recipe,
    required this.pickerMode,
    required this.onTap,
    required this.onDelete,
    required this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu),
        title: Text(recipe.name),
        subtitle: Text(
          '${recipe.servingSize.toStringAsFixed(0)} ${recipe.servingLabel}',
        ),
        trailing: pickerMode
            ? const Icon(Icons.chevron_right)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: onTap,
                    tooltip: 'Edit recipe',
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: onDuplicate,
                    tooltip: 'Duplicate recipe',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                    tooltip: 'Delete recipe',
                  ),
                ],
              ),
        onTap: onTap,
        onLongPress: pickerMode ? null : onDelete,
      ),
    );
  }
}
