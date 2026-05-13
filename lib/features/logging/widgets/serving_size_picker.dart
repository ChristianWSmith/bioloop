import 'package:flutter/material.dart';

class ServingSizePicker extends StatelessWidget {
  final double servings;
  final ValueChanged<double> onChanged;
  final double? servingSizeGrams;
  final TextEditingController gramController;
  final ValueChanged<String> onGramChanged;

  const ServingSizePicker({
    super.key,
    required this.servings,
    required this.onChanged,
    this.servingSizeGrams,
    required this.gramController,
    required this.onGramChanged,
  });

  void _decrement() {
    final next = servings - 0.5;
    if (next >= 0.5) onChanged(next);
  }

  void _increment() {
    onChanged(servings + 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Servings',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: _decrement,
            ),
            SizedBox(
              width: 64,
              child: Text(
                servings.toStringAsFixed(servings == servings.roundToDouble()
                    ? 0
                    : 1),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            IconButton(
              key: const Key('increment_servings'),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: _increment,
            ),
          ],
        ),
        if (servingSizeGrams != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: gramController,
                  decoration: const InputDecoration(
                    labelText: 'Grams',
                    isDense: true,
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: onGramChanged,
                ),
              ),
              const SizedBox(width: 8),
              const Text('g'),
            ],
          ),
        ],
      ],
    );
  }
}
