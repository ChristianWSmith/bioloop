import 'package:flutter/material.dart';

const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const _mealLabels = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'dinner': 'Dinner',
  'snack': 'Snack',
};
const _mealIcons = {
  'breakfast': Icons.free_breakfast,
  'lunch': Icons.lunch_dining,
  'dinner': Icons.dinner_dining,
  'snack': Icons.cookie,
};

class MealTypeSelector extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onChanged;

  const MealTypeSelector({
    super.key,
    this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Meal type',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _mealTypes.map((type) {
            final isSelected = selected == type;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _mealIcons[type],
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(_mealLabels[type]!),
                ],
              ),
              selected: isSelected,
              onSelected: (_) => onChanged(type),
            );
          }).toList(),
        ),
      ],
    );
  }
}
