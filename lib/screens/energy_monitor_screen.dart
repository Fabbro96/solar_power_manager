import 'package:flutter/material.dart';

import '../controllers/energy_controller.dart';
import '../models/energy_data.dart';
import '../models/power_sample.dart';
import '../theme/app_theme.dart';
import '../widgets/energy_info_card.dart';
import '../widgets/power_chart.dart';

class EnergyMonitorScreen extends StatefulWidget {
  final EnergyController controller;

  /// Called after a new IP is validated and applied — used to persist it.
  final Future<void> Function(String)? onIpSaved;

  const EnergyMonitorScreen({
    super.key,
    required this.controller,
    this.onIpSaved,
  });

  @override
  State<EnergyMonitorScreen> createState() => _EnergyMonitorScreenState();
}

class _EnergyMonitorScreenState extends State<EnergyMonitorScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.start();
  }

  @override
  void dispose() {
    widget.controller.stop();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _getAppBarTitle(MonitorState state) {
    if (state.inverterStatus == ConnectionStatus.connected) {
      return 'Solar Monitor: connected';
    }
    if (state.errorDetail != null) {
      return 'Solar Monitor: error [${state.errorDetail}]';
    }
    return 'Solar Monitor';
  }

  Widget _buildAppBarTitle(MonitorState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _getAppBarTitle(state),
          style: AppTextStyles.appBarTitle.copyWith(fontSize: 18),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Last update: ${state.energyData.lastUpdate}',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  String _monitorStatusLabel(MonitorState state) {
    switch (state.inverterStatus) {
      case ConnectionStatus.connected:
        return 'Solar Monitor: connected';
      case ConnectionStatus.error:
        return 'Solar Monitor: disconnected';
      case ConnectionStatus.checking:
        return 'Solar Monitor: checking...';
    }
  }

  Color _monitorStatusColor(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return const Color(0xFF66E4A8);
      case ConnectionStatus.error:
        return const Color(0xFFFF8A8A);
      case ConnectionStatus.checking:
        return Colors.amberAccent;
    }
  }

  IconData _monitorStatusIcon(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return Icons.solar_power;
      case ConnectionStatus.error:
        return Icons.solar_power_outlined;
      case ConnectionStatus.checking:
        return Icons.settings_input_component;
    }
  }

  // ── IP warning ────────────────────────────────────────────────────

  /// Show the warning banner when there is no usable data or a connection
  /// error — both conditions usually mean the inverter IP is wrong.
  bool _shouldWarnAboutIp(MonitorState state) {
    if (state.inverterStatus == ConnectionStatus.checking) return false;
    if (state.inverterStatus == ConnectionStatus.error) return true;
    return state.energyData.todaysEnergy == 'N/A' &&
        state.energyData.powerNow == 'N/A';
  }

  // ── IP Settings dialog ────────────────────────────────────────────

  Future<void> _showIpDialog(BuildContext context) async {
    final current = widget.controller.currentInverterIp;
    final ipController = TextEditingController(text: current);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text(
            'Inverter IP address',
            style: TextStyle(color: Colors.white70),
          ),
          content: TextField(
            controller: ipController,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'IP address',
              labelStyle: const TextStyle(color: Colors.white54),
              hintText: '192.168.x.x',
              hintStyle: const TextStyle(color: Colors.white24),
              errorText: errorText,
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
              ),
            ),
            onChanged: (_) {
              if (errorText != null) setDialogState(() => errorText = null);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                final ip = ipController.text.trim();
                if (ip.isEmpty) {
                  setDialogState(() => errorText = 'Enter an IP address');
                  return;
                }
                if (!_isValidIp(ip)) {
                  setDialogState(() => errorText = 'Invalid IP address');
                  return;
                }
                Navigator.pop(ctx);
                await widget.controller.updateInverterIp(ip);
                await widget.onIpSaved?.call(ip);
              },
              child: Text(
                'Save',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );

    ipController.dispose();
  }

  static bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    return parts.every((p) {
      final n = int.tryParse(p);
      return n != null && n >= 0 && n <= 255;
    });
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          appBar: AppBar(
            title: _buildAppBarTitle(state),
            actions: [
              IconButton(
                tooltip: 'Change inverter IP',
                icon: const Icon(
                  Icons.settings_ethernet,
                  color: Colors.white54,
                ),
                onPressed: () => _showIpDialog(context),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_shouldWarnAboutIp(state)) _buildIpWarning(context, state),
              Expanded(child: _buildBody(state)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIpWarning(BuildContext context, MonitorState state) {
    final reason = state.inverterStatus == ConnectionStatus.error
        ? (state.errorDetail ?? 'Connection error')
        : 'Inverter returned no data';
    return Container(
      width: double.infinity,
      color: Colors.orange.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$reason — check the inverter IP address.',
              style: const TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => _showIpDialog(context),
            child: const Text(
              'Change IP',
              style: TextStyle(color: Colors.orange, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(MonitorState state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        widget.controller.updateViewportWidth(constraints.maxWidth);
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        final horizontalPadding = constraints.maxWidth < 700 ? 12.0 : 16.0;
        final verticalPadding = constraints.maxHeight < 600 ? 10.0 : 14.0;
        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: isLandscape
              ? _buildLandscape(constraints, state)
              : _buildPortrait(state),
        );
      },
    );
  }

  // ── Landscape ─────────────────────────────────────────────────────

  Widget _buildLandscape(BoxConstraints constraints, MonitorState state) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _rangeSelector(state),
              const SizedBox(height: 6),
              _chartStats(state),
              const SizedBox(height: 6),
              Expanded(
                child: _buildChartPanel(state),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(flex: 2, child: _infoPanel(state)),
      ],
    );
  }

  // ── Portrait ──────────────────────────────────────────────────────

  Widget _buildPortrait(MonitorState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: EnergyInfoCard(
                label: 'Current Power',
                value: state.energyData.powerNow,
                icon: Icons.bolt,
              ),
            ),
            Expanded(
              child: EnergyInfoCard(
                label: 'Today',
                value: state.energyData.todaysEnergy,
                icon: Icons.calendar_today,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _rangeSelector(state),
        const SizedBox(height: 6),
        _chartStats(state),
        const SizedBox(height: 6),
        Expanded(
          child: _buildChartPanel(state),
        ),
        const SizedBox(height: 6),
        _statusAndRefreshRow(state),
      ],
    );
  }

  Widget _buildChartPanel(MonitorState state) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Stack(
        children: [
          PowerChart(
            data: state.powerHistory,
            chartRange: state.chartRange,
            showBottomTitles: true,
          ),
          if (state.chartLoading)
            const Positioned.fill(
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────

  Widget _infoPanel(MonitorState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EnergyInfoCard(
          label: 'Current Power',
          value: state.energyData.powerNow,
          icon: Icons.bolt,
        ),
        EnergyInfoCard(
          label: 'Today',
          value: state.energyData.todaysEnergy,
          icon: Icons.calendar_today,
        ),
        const SizedBox(height: 8),
        _statusAndRefreshRow(state),
      ],
    );
  }

  Widget _statusAndRefreshRow(MonitorState state) {
    final statusColor = _monitorStatusColor(state.inverterStatus);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withAlpha(140)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(
            _monitorStatusIcon(state.inverterStatus),
            size: 16,
            color: statusColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _monitorStatusLabel(state),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Last update: ${state.energyData.lastUpdate}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _refreshButton(compact: true),
        ],
      ),
    );
  }

  Widget _refreshButton({bool compact = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: widget.controller.refresh,
        ),
        if (!compact)
          const Text('Auto-refresh active', style: AppTextStyles.muted),
      ],
    );
  }

  Widget _rangeSelector(MonitorState state) {
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
              onSelected: (_) => widget.controller.setChartRange(range),
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

  Widget _chartStats(MonitorState state) {
    String format(double? v) => v == null ? '--' : '${v.toStringAsFixed(0)} W';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statChip('MIN', format(state.minPower)),
        _statChip('AVG', format(state.avgPower)),
        _statChip('MAX', format(state.maxPower)),
        _statChip('SAMPLES', '${state.powerHistory.length}'),
        _vsAvgChip(state),
      ],
    );
  }

  Widget _vsAvgChip(MonitorState state) {
    final delta = state.deltaVsAverage;
    final percent = state.percentVsAverage;

    if (delta == null || percent == null) {
      return _statChip('NOW vs AVG', '--');
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

  Widget _statChip(String label, String value) {
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
