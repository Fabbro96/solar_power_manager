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
        final metrics = _computeMetrics(data);
        final spots = metrics.spots;
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
                minY: metrics.minY,
                maxY: metrics.maxY,
                gridData: _buildGridData(xInterval, metrics.yAxisInterval),
                titlesData: _buildTitlesData(spots, xInterval, metrics),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.white12),
                ),
                extraLinesData: _buildReferenceLines(metrics),
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

  FlGridData _buildGridData(double xInterval, double yInterval) {
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

  FlTitlesData _buildTitlesData(
    List<FlSpot> spots,
    double xInterval,
    _ChartMetrics metrics,
  ) {
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
          interval: metrics.yAxisInterval,
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

  ExtraLinesData _buildReferenceLines(_ChartMetrics metrics) {
    // Also skip when all values are identical (flat line): the lines would
    // both render at the same y, cluttering the baseline (common at night).
    if (metrics.spots.length < 2 || metrics.max == metrics.min) {
      return const ExtraLinesData(horizontalLines: []);
    }

    final avg = metrics.avg;
    final max = metrics.max;

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

  double _xIntervalForWidth(double chartWidth) {
    if (data.length <= 1) return 10;
    final first = data.first.timestamp.millisecondsSinceEpoch / 1000;
    final last = data.last.timestamp.millisecondsSinceEpoch / 1000;
    final range = last - first;
    if (range == 0) return 10;

    final baseStepSeconds = _baseXAxisStep(chartRange).inSeconds.toDouble();
    final minLabelWidth =
        chartRange.duration > const Duration(days: 1) ? 56.0 : 68.0;
    final maxLabels = (chartWidth / minLabelWidth).floor().clamp(3, 10);

    final labelsAtBase = (range / baseStepSeconds).ceil();
    final multiplier =
        labelsAtBase <= maxLabels ? 1 : (labelsAtBase / maxLabels).ceil();

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

  _ChartMetrics _computeMetrics(List<PowerSample> samples) {
    if (samples.isEmpty) {
      return const _ChartMetrics(
        spots: <FlSpot>[],
        min: 0,
        max: 0,
        avg: 0,
        minY: 0,
        maxY: 1000,
        yAxisInterval: 100,
      );
    }

    var min = samples.first.watts;
    var max = samples.first.watts;
    var total = 0.0;
    final spots = List<FlSpot>.generate(
      samples.length,
      (index) {
        final watts = samples[index].watts;
        if (watts < min) min = watts;
        if (watts > max) max = watts;
        total += watts;
        return FlSpot(
          samples[index].timestamp.millisecondsSinceEpoch / 1000,
          watts,
        );
      },
      growable: false,
    );

    final avg = total / samples.length;
    final paddedMin = min - (min * 0.15);
    final minY = paddedMin < 0 ? 0.0 : paddedMin;
    final maxY = max + (max * 0.12) + 40.0;

    double interval;
    if (max < 500) {
      interval = 100;
    } else if (max < 1000) {
      interval = 200;
    } else if (max < 2000) {
      interval = 500;
    } else if (max < 5000) {
      interval = 1000;
    } else {
      interval = 2000;
    }

    return _ChartMetrics(
      spots: spots,
      min: min,
      max: max,
      avg: avg,
      minY: minY,
      maxY: maxY,
      yAxisInterval: interval,
    );
  }
}

class _ChartMetrics {
  final List<FlSpot> spots;
  final double min;
  final double max;
  final double avg;
  final double minY;
  final double maxY;
  final double yAxisInterval;

  const _ChartMetrics({
    required this.spots,
    required this.min,
    required this.max,
    required this.avg,
    required this.minY,
    required this.maxY,
    required this.yAxisInterval,
  });
}
