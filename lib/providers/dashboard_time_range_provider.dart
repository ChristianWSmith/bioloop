import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TimeRange { oneMonth, sixMonths, allTime }

final dashboardTimeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.oneMonth);
