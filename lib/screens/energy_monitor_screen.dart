import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

enum _EnergyMonitorMenuAction { changeIp, showLogs, clearLogs }

class _EnergyMonitorScreenState extends State<EnergyMonitorScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    switch (state) {
      case AppLifecycleState.resumed:
        widget.controller.start();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        widget.controller.stop();
        break;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _monitorStatusLabel(MonitorState state) {
    switch (state.inverterStatus) {
      case ConnectionStatus.connected:
        return 'Inverter connected';
      case ConnectionStatus.error:
        return 'Inverter disconnected';
      case ConnectionStatus.checking:
        return 'Connection check in progress...';
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
    final parts = _splitIpIntoOctets(current);
    final c1 = TextEditingController(text: parts[0]);
    final c2 = TextEditingController(text: parts[1]);
    final c3 = TextEditingController(text: parts[2]);
    final c4 = TextEditingController(text: parts[3]);
    final f1 = FocusNode();
    final f2 = FocusNode();
    final f3 = FocusNode();
    final f4 = FocusNode();

    String? errorText;
    String? probeMessage;
    bool probeOk = false;
    bool isProbing = false;
    bool isSaving = false;

    String composeIp() =>
        '${c1.text.trim()}.${c2.text.trim()}.${c3.text.trim()}.${c4.text.trim()}';

    Future<void> runProbe(StateSetter setDialogState) async {
      final ip = composeIp();
      if (!_isValidIp(ip)) {
        setDialogState(() {
          errorText = 'Invalid IP address';
          probeMessage = null;
          probeOk = false;
        });
        return;
      }

      setDialogState(() {
        isProbing = true;
        errorText = null;
        probeMessage = null;
        probeOk = false;
      });

      final result = await widget.controller.probeInverterIp(ip);
      if (!mounted) return;

      setDialogState(() {
        isProbing = false;
        probeMessage = result.message;
        probeOk = result.success;
      });
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF111111),
          title: const Text(
            'Inverter IP address',
            style: TextStyle(color: Colors.white70),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current configuration',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                current,
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const SizedBox(height: 14),
              const Text(
                'New IPv4 address',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _octetField(c1, f1, f2, setDialogState)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('.', style: TextStyle(color: Colors.white70)),
                  ),
                  Expanded(child: _octetField(c2, f2, f3, setDialogState)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('.', style: TextStyle(color: Colors.white70)),
                  ),
                  Expanded(child: _octetField(c3, f3, f4, setDialogState)),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('.', style: TextStyle(color: Colors.white70)),
                  ),
                  Expanded(child: _octetField(c4, f4, null, setDialogState)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: isProbing || isSaving
                        ? null
                        : () => runProbe(setDialogState),
                    icon: isProbing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.network_check),
                    label: Text(isProbing ? 'Testing...' : 'Test connection'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      composeIp(),
                      style: const TextStyle(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
              if (probeMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  probeMessage!,
                  style: TextStyle(
                    color: probeOk ? const Color(0xFF66E4A8) : Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(ctx);
                final ip = composeIp();
                if (!_isValidIp(ip)) {
                  setDialogState(() => errorText = 'Invalid IP address');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                  errorText = null;
                });

                if (!probeOk) {
                  final probeResult =
                      await widget.controller.probeInverterIp(ip);
                  if (!mounted) return;

                  if (!probeResult.success) {
                    setDialogState(() {
                      isSaving = false;
                      probeMessage = probeResult.message;
                      probeOk = false;
                    });
                    return;
                  }
                }

                try {
                  await widget.controller.updateInverterIp(ip);
                  await widget.onIpSaved?.call(ip);
                  if (!mounted) return;
                  navigator.pop();
                } catch (e) {
                  if (!mounted) return;
                  setDialogState(() {
                    errorText = 'Save failed: $e';
                    isSaving = false;
                  });
                  return;
                }
              },
              child: Text(
                isSaving ? 'Saving...' : 'Apply',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );

    c1.dispose();
    c2.dispose();
    c3.dispose();
    c4.dispose();
    f1.dispose();
    f2.dispose();
    f3.dispose();
    f4.dispose();
  }

  Future<void> _showLogsDialog(BuildContext context) async {
    final logs = await widget.controller.readAllLogs();
    final path = widget.controller.logFilePath;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('App logs', style: TextStyle(color: Colors.white70)),
        content: SizedBox(
          width: double.maxFinite,
          height: 280,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (path != null) ...[
                Text('Log file: $path',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    logs.isEmpty ? 'No log entries.' : logs,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearLogs(BuildContext context) async {
    await widget.controller.clearLogs();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs cleared')),
    );
  }

  static List<String> _splitIpIntoOctets(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) {
      return const ['192', '168', '1', '16'];
    }
    return parts;
  }

  Widget _octetField(
    TextEditingController controller,
    FocusNode focus,
    FocusNode? next,
    StateSetter setDialogState,
  ) {
    return TextField(
      controller: controller,
      focusNode: focus,
      maxLength: 3,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        counterText: '',
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: Colors.white70),
        ),
      ),
      onChanged: (value) {
        if (value.length >= 3 && next != null) {
          next.requestFocus();
        }

        // Trigger refresh of preview text/probe status area.
        setDialogState(() {});
      },
    );
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
            title: const SizedBox.shrink(),
            leading: IconButton(
              tooltip: 'Change inverter IP',
              icon: const Icon(
                Icons.settings_ethernet,
                color: Colors.white54,
              ),
              onPressed: () => _showIpDialog(context),
            ),
            actions: [
              PopupMenuButton<_EnergyMonitorMenuAction>(
                icon: const Icon(Icons.more_vert, color: Colors.white54),
                color: const Color(0xFF111111),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: _EnergyMonitorMenuAction.changeIp,
                    child: Text('Change inverter IP'),
                  ),
                  const PopupMenuItem(
                    value: _EnergyMonitorMenuAction.showLogs,
                    child: Text('Show logs'),
                  ),
                  const PopupMenuItem(
                    value: _EnergyMonitorMenuAction.clearLogs,
                    child: Text('Clear logs'),
                  ),
                ],
                onSelected: (action) {
                  switch (action) {
                    case _EnergyMonitorMenuAction.changeIp:
                      _showIpDialog(context);
                      break;
                    case _EnergyMonitorMenuAction.showLogs:
                      _showLogsDialog(context);
                      break;
                    case _EnergyMonitorMenuAction.clearLogs:
                      _clearLogs(context);
                      break;
                  }
                },
              ),
            ],
          ),
          body: Column(
            children: [
              if (_shouldWarnAboutIp(state)) _buildIpWarning(context, state),
              if (widget.controller.availableRelease != null)
                _buildUpdateAvailableNotification(context),
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

  Widget _buildUpdateAvailableNotification(BuildContext context) {
    final release = widget.controller.availableRelease;
    if (release == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.blue.withAlpha(30),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_download, color: Colors.blue, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Version ${release.tagName} available',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () {
                  widget.controller.dismissUpdateNotification();
                },
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
              TextButton(
                onPressed: () {
                  _openReleaseLink(release);
                },
                child: const Text(
                  'Get it',
                  style: TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openReleaseLink(dynamic release) {
    // For now, show a snackbar. In production, use url_launcher to open GitHub releases
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Visit GitHub releases for version ${release.tagName}'),
        action: SnackBarAction(label: 'OK', onPressed: () {}),
      ),
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
    final latestLog = widget.controller.latestLog;

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
                if (latestLog != null)
                  Text(
                    latestLog.toConsoleLine(),
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
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
