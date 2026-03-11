import 'package:flutter/material.dart';

import '../controllers/energy_controller.dart';
import '../models/energy_data.dart';
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
            title: Text(_getAppBarTitle(state)),
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
        final isLandscape = constraints.maxWidth > constraints.maxHeight;
        return Padding(
          padding: const EdgeInsets.all(20),
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
              Text(
                _getInternetLabel(state),
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
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
