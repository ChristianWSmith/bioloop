import 'package:flutter/material.dart';
import '../../../core/database/database.dart';

class RecipeIngredientRow extends StatelessWidget {
  final IngredientWithFood item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RecipeIngredientRow({
    super.key,
    required this.item,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final food = item.food;
    final ingredient = item.ingredient;
    final cals = food.caloriesPerServing * ingredient.quantity;

    return ListTile(
      leading: const Icon(Icons.restaurant),
      title: Text(food.name),
      subtitle: Text(
        '${ingredient.quantity.toStringAsFixed(1)} × ${food.servingLabel} — ${cals.toStringAsFixed(0)} kcal',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: onEdit,
              tooltip: 'Edit quantity',
            ),
          if (onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: onDelete,
              tooltip: 'Remove ingredient',
            ),
        ],
      ),
    );
  }
}
