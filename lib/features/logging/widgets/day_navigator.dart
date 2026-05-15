import 'package:flutter/material.dart';

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

class DayNavigator extends StatelessWidget {
  final DateTime currentDate;
  final ValueChanged<DateTime> onDateChanged;

  const DayNavigator({
    super.key,
    required this.currentDate,
    required this.onDateChanged,
  });

  String _formatDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(currentDate).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return '${_monthNames[currentDate.month - 1]} ${currentDate.day}, ${currentDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onDateChanged(currentDate.subtract(const Duration(days: 1))),
        ),
        Text(_formatDate(), style: Theme.of(context).textTheme.titleMedium),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onDateChanged(currentDate.add(const Duration(days: 1))),
        ),
      ],
    );
  }
}
