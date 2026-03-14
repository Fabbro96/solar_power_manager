import 'package:flutter/material.dart';
import '../../models/energy_data.dart';
import '../../models/power_sample.dart';
import '../../theme/app_theme.dart';

class ChartRangeSelector extends StatelessWidget {
  final MonitorState state;
  final ValueChanged<ChartRange> onRangeSelected;

  const ChartRangeSelector({
    super.key,
    required this.state,
    required this.onRangeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ChartRange.values.map((range) {
          final selected = range == state.chartRange;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(range.label),
              selected: selected,
              onSelected: (_) => onRangeSelected(range),
              labelStyle: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
              selectedColor: AppColors.accent,
              backgroundColor: const Color(0xFF111111),
              side: const BorderSide(color: Colors.white12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}
