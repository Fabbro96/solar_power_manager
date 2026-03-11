import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/power_sample.dart';
import '../theme/app_theme.dart';

class PowerChart extends StatelessWidget {
  final List<PowerSample> data;
  final ChartRange chartRange;
  final bool showBottomTitles;

  const PowerChart({
    super.key,
    required this.data,
    this.chartRange = ChartRange.last24Hours,
    this.showBottomTitles = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spots = _spots;
        final hasData = spots.isNotEmpty;
        final chartWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final xInterval = _xIntervalForWidth(chartWidth);

        return Stack(
          children: [
            LineChart(
              LineChartData(
                backgroundColor: AppColors.background,
                minX: hasData ? spots.first.x : 0,
                maxX: hasData ? spots.last.x : 1,
                minY: _minY,
                maxY: _maxY,
                gridData: _buildGridData(spots, xInterval),
                titlesData: _buildTitlesData(spots, xInterval),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white12),
                ),
                extraLinesData: _buildReferenceLines(),
                lineTouchData: _buildTouchData(spots),
                lineBarsData: [_buildLineData(spots)],
              ),
            ),
            if (!hasData)
              const Positioned.fill(
                child: Center(
                  child: Text(
                    'No history in selected range',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  FlGridData _buildGridData(List<FlSpot> spots, double xInterval) {
    final yInterval = _yAxisInterval;

    return FlGridData(
      show: true,
      drawVerticalLine: showBottomTitles,
      drawHorizontalLine: true,
      verticalInterval: xInterval,
      horizontalInterval: yInterval,
      getDrawingHorizontalLine: (_) => const FlLine(
        color: AppColors.gridLine,
        strokeWidth: 1,
        dashArray: [5, 5],
      ),
      getDrawingVerticalLine: (_) => const FlLine(
        color: AppColors.gridLine,
        strokeWidth: 1,
        dashArray: [5, 5],
      ),
    );
  }

  FlTitlesData _buildTitlesData(List<FlSpot> spots, double xInterval) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showBottomTitles,
          reservedSize: 34,
          interval: xInterval,
          getTitlesWidget: _bottomTitleWidget,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: _yAxisInterval,
          reservedSize: 48,
          getTitlesWidget: (value, meta) {
            if (spots.isEmpty) return const Text('');
            return Text('${value.toInt()} W', style: AppTextStyles.axisLabel);
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _bottomTitleWidget(double value, TitleMeta meta) {
    if (data.isEmpty) {
      return SideTitleWidget(axisSide: meta.axisSide, child: const Text(''));
    }

    final sampleTime =
        DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
    final labelFormat =
        chartRange.duration > const Duration(days: 1) ? 'dd/MM' : 'HH:mm';

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(
        DateFormat(labelFormat).format(sampleTime),
        style: AppTextStyles.axisTick,
        maxLines: 1,
        overflow: TextOverflow.fade,
      ),
    );
  }

  LineChartBarData _buildLineData(List<FlSpot> spots) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.28,
      color: AppColors.accent,
      barWidth: 2.8,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: data.length <= 8,
        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
          radius: 2.4,
          color: AppColors.accent,
          strokeColor: AppColors.background,
          strokeWidth: 1.2,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: const LinearGradient(
          colors: [
            Color.fromRGBO(0, 255, 255, 0.7),
            Color.fromRGBO(0, 255, 255, 0.01),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(List<FlSpot> spots) {
    return LineTouchData(
      enabled: spots.isNotEmpty,
      handleBuiltInTouches: true,
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor: (_) => const Color(0xE61A1D21),
        fitInsideHorizontally: true,
        fitInsideVertically: true,
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((touched) {
            final index = touched.spotIndex.clamp(0, data.length - 1);
            final sample = data[index];
            final time = DateFormat('dd/MM HH:mm:ss').format(sample.timestamp);
            return LineTooltipItem(
              '$time\n${sample.watts.toStringAsFixed(0)} W',
              const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  ExtraLinesData _buildReferenceLines() {
    if (data.length < 2) {
      return const ExtraLinesData(horizontalLines: []);
    }

    final avg = data.map((s) => s.watts).reduce((a, b) => a + b) / data.length;
    final max = data.map((s) => s.watts).reduce((a, b) => a > b ? a : b);

    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: avg,
          color: const Color(0xFFEEB439).withAlpha(170),
          strokeWidth: 1,
          dashArray: const [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 6),
            style: const TextStyle(
              color: Colors.amber,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            labelResolver: (_) => 'AVG ${avg.toStringAsFixed(0)} W',
          ),
        ),
        HorizontalLine(
          y: max,
          color: const Color(0xFFFF6B6B).withAlpha(190),
          strokeWidth: 1.2,
          dashArray: const [3, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 6),
            style: const TextStyle(
              color: Color(0xFFFF8A8A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
            labelResolver: (_) => 'MAX ${max.toStringAsFixed(0)} W',
          ),
        ),
      ],
    );
  }

  List<FlSpot> get _spots {
    if (data.isEmpty) return const [];
    return List<FlSpot>.generate(
      data.length,
      (index) => FlSpot(
        data[index].timestamp.millisecondsSinceEpoch / 1000,
        data[index].watts,
      ),
      growable: false,
    );
  }

  double _xIntervalForWidth(double chartWidth) {
    if (data.length <= 1) return 10;
    final first = data.first.timestamp.millisecondsSinceEpoch / 1000;
    final last = data.last.timestamp.millisecondsSinceEpoch / 1000;
    final range = last - first;
    if (range == 0) return 10;

    final baseStepSeconds = _baseXAxisStep(chartRange).inSeconds.toDouble();
    final minLabelWidth = chartRange.duration > const Duration(days: 1)
        ? 56.0
        : 68.0;
    final maxLabels = (chartWidth / minLabelWidth).floor().clamp(3, 10);

    final labelsAtBase = (range / baseStepSeconds).ceil();
    final multiplier = labelsAtBase <= maxLabels
        ? 1
        : (labelsAtBase / maxLabels).ceil();

    return baseStepSeconds * multiplier;
  }

  Duration _baseXAxisStep(ChartRange range) {
    switch (range) {
      case ChartRange.lastHour:
        return const Duration(minutes: 5);
      case ChartRange.last24Hours:
        return const Duration(minutes: 30);
      case ChartRange.last7Days:
        return const Duration(hours: 3);
      case ChartRange.last30Days:
        return const Duration(hours: 12);
      case ChartRange.last90Days:
        return const Duration(days: 1);
    }
  }

  double get _yAxisInterval {
    if (data.isEmpty) return 100;
    final maxY = data.map((s) => s.watts).reduce((a, b) => a > b ? a : b);
    if (maxY < 500) return 100;
    if (maxY < 1000) return 200;
    if (maxY < 2000) return 500;
    if (maxY < 5000) return 1000;
    return 2000;
  }

  double get _minY {
    if (data.isEmpty) return 0;
    final min = data.map((s) => s.watts).reduce((a, b) => a < b ? a : b);
    final padded = min - (min * 0.15);
    return padded < 0 ? 0 : padded;
  }

  double get _maxY {
    if (data.isEmpty) return 1000;
    final max = data.map((s) => s.watts).reduce((a, b) => a > b ? a : b);
    return max + (max * 0.12) + 40;
  }
}
