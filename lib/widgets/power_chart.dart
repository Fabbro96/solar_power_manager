import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';

class PowerChart extends StatelessWidget {
  final List<FlSpot> data;
  final bool showBottomTitles;

  const PowerChart({
    super.key,
    required this.data,
    this.showBottomTitles = true,
  });

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        backgroundColor: AppColors.background,
        gridData: _buildGridData(),
        titlesData: _buildTitlesData(),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.white12),
        ),
        lineBarsData: [_buildLineData()],
      ),
    );
  }

  FlGridData _buildGridData() {
    final xInterval = _xInterval;
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

  FlTitlesData _buildTitlesData() {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: showBottomTitles,
          reservedSize: 28,
          interval: _xInterval,
          getTitlesWidget: _bottomTitleWidget,
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: _yAxisInterval,
          reservedSize: 40,
          getTitlesWidget: (value, meta) {
            if (data.isEmpty) return const Text('');
            return Text('${value.toInt()}W', style: AppTextStyles.axisLabel);
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

    final secondsAgo = (data.last.x - value).toInt() * 5;
    final dateTime = DateTime.now().subtract(Duration(seconds: secondsAgo));
    final span = data.last.x - data.first.x;
    // < ~12min of data → show minutes only, otherwise HH:mm
    final format = span < 720 ? 'mm' : 'HH:mm';

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(DateFormat(format).format(dateTime),
          style: AppTextStyles.axisTick),
    );
  }

  LineChartBarData _buildLineData() {
    return LineChartBarData(
      spots: data,
      isCurved: true,
      curveSmoothness: 0.4,
      color: AppColors.accent,
      barWidth: 3,
      dotData: const FlDotData(show: false),
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

  double get _xInterval {
    if (data.length <= 1) return 10;
    final range = data.last.x - data.first.x;
    return range == 0 ? 10 : range / 6;
  }

  double get _yAxisInterval {
    if (data.isEmpty) return 100;
    final maxY = data.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    if (maxY < 500) return 100;
    if (maxY < 1000) return 200;
    if (maxY < 2000) return 500;
    if (maxY < 5000) return 1000;
    return 2000;
  }
}
