import 'package:flutter/material.dart';

import '../controllers/energy_controller.dart';
import '../models/energy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/energy_info_card.dart';
import '../widgets/power_chart.dart';

class EnergyMonitorScreen extends StatefulWidget {
  final EnergyController controller;

  const EnergyMonitorScreen({super.key, required this.controller});

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
    // Only stop the internal timers but do not dispose the controller here
    // unless this screen inherently "owns" it. For now, just stop its background ops.
    widget.controller.stop();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────────────

  String _getAppBarTitle(MonitorState state) {
    if (state.inverterStatus == ConnectionStatus.connected) {
      return 'Solar Monitor: connected';
    }
    if (state.errorDetail != null) {
      return 'Solar Monitor: error [${state.errorDetail}]';
    }
    return 'Solar Monitor';
  }

  String _getInternetLabel(MonitorState state) {
    switch (state.internetStatus) {
      case ConnectionStatus.connected:
        return 'Internet: connected';
      case ConnectionStatus.error:
        return 'Internet: disconnected';
      case ConnectionStatus.checking:
        return 'Internet: checking...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        return Scaffold(
          appBar: AppBar(title: Text(_getAppBarTitle(state))),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              return Padding(
                padding: const EdgeInsets.all(20),
                child: isLandscape
                    ? _buildLandscape(constraints, state)
                    : _buildPortrait(state),
              );
            },
          ),
        );
      },
    );
  }

  // ── Landscape ─────────────────────────────────────────────────────

  Widget _buildLandscape(BoxConstraints constraints, MonitorState state) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _lastUpdateText(state),
              SizedBox(
                height: constraints.maxHeight * 0.6,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 10),
                  child: PowerChart(data: state.powerHistory),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        Expanded(child: _infoPanel(state)),
      ],
    );
  }

  // ── Portrait ──────────────────────────────────────────────────────

  Widget _buildPortrait(MonitorState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lastUpdateText(state),
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
        const SizedBox(height: 20),
        Expanded(
          child: PowerChart(data: state.powerHistory, showBottomTitles: false),
        ),
        const Spacer(),
        Center(
          child: Column(
            children: [
              Text(_getInternetLabel(state),
                  style: const TextStyle(color: Colors.white70, fontSize: 14)),
              _refreshButton(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared pieces ─────────────────────────────────────────────────

  Widget _lastUpdateText(MonitorState state) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        'Last update: ${state.energyData.lastUpdate}',
        style: AppTextStyles.subtitle,
      ),
    );
  }

  Widget _infoPanel(MonitorState state) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
        const SizedBox(height: 40),
        Center(child: _refreshButton()),
      ],
    );
  }

  Widget _refreshButton() {
    return Column(
      children: [
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.label),
          onPressed: widget.controller.refresh,
        ),
        const Text('Auto-refresh active', style: AppTextStyles.muted),
      ],
    );
  }
}
