import 'package:flutter/material.dart';
import '../../models/energy_data.dart';

class ChartStatsRow extends StatelessWidget {
  final MonitorState state;

  const ChartStatsRow({
    super.key,
    required this.state,
  });

  String _format(double? v) => v == null ? '--' : '${v.toStringAsFixed(0)} W';

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ChartStatChip(label: 'MIN', value: _format(state.minPower)),
        _ChartStatChip(label: 'AVG', value: _format(state.avgPower)),
        _ChartStatChip(label: 'MAX', value: _format(state.maxPower)),
        _ChartStatChip(label: 'SAMPLES', value: '${state.powerHistory.length}'),
        _VsAvgChip(state: state),
      ],
    );
  }
}

class _ChartStatChip extends StatelessWidget {
  final String label;
  final String value;

  const _ChartStatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VsAvgChip extends StatelessWidget {
  final MonitorState state;

  const _VsAvgChip({required this.state});

  @override
  Widget build(BuildContext context) {
    final delta = state.deltaVsAverage;
    final percent = state.percentVsAverage;

    if (delta == null || percent == null) {
      return const _ChartStatChip(label: 'NOW vs AVG', value: '--');
    }

    final sign = delta >= 0 ? '+' : '';
    final color =
        delta >= 0 ? const Color(0xFF66E4A8) : const Color(0xFFFF8A8A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            const TextSpan(
              text: 'NOW vs AVG ',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text:
                  '$sign${delta.toStringAsFixed(0)} W ($sign${percent.toStringAsFixed(1)}%)',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
