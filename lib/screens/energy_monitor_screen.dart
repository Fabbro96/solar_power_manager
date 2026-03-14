import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../controllers/energy_controller.dart';
import '../models/energy_data.dart';
import '../services/apk_install_service.dart';
import '../theme/app_theme.dart';
import 'settings_screen.dart';
import '../widgets/energy_info_card.dart';
import '../widgets/power_chart.dart';
import '../widgets/ip_warning_bar.dart';
import '../widgets/update_notification_bar.dart';
import 'widgets/chart_range_selector.dart';
import 'widgets/chart_stats_row.dart';

class EnergyMonitorScreen extends StatefulWidget {
  final EnergyController controller;

  /// Called after new settings are validated and applied — used to persist them.
  final Future<void> Function(String ip, String username, String password)?
      onSettingsSaved;

  const EnergyMonitorScreen({
    super.key,
    required this.controller,
    this.onSettingsSaved,
  });

  @override
  State<EnergyMonitorScreen> createState() => _EnergyMonitorScreenState();
}

enum _EnergyMonitorMenuAction { changeIp, showLogs, clearLogs, checkUpdates }

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

  Future<void> _showSettingsDialog(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(
          controller: widget.controller,
          onSettingsSaved: widget.onSettingsSaved,
        ),
      ),
    );
  }

  Future<void> _showLogsDialog(BuildContext context) async {
    final logs = await widget.controller.readAllLogs();
    final path = widget.controller.logFilePath;

    if (!context.mounted) return;

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
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
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
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearLogs(BuildContext context) async {
    await widget.controller.clearLogs();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logs cleared')),
    );
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
              onPressed: () => _showSettingsDialog(context),
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
                    value: _EnergyMonitorMenuAction.checkUpdates,
                    child: Text('Check for updates'),
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
                      _showSettingsDialog(context);
                      break;
                    case _EnergyMonitorMenuAction.checkUpdates:
                      _checkUpdatesManually();
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
              if (_shouldWarnAboutIp(state))
                IpWarningBar(
                  reason: state.inverterStatus == ConnectionStatus.error
                      ? (state.errorDetail ?? 'Connection error')
                      : 'Inverter returned no data',
                  onChangeIp: () => _showSettingsDialog(context),
                ),
              if (widget.controller.availableRelease != null)
                UpdateNotificationBar(
                  tagName: widget.controller.availableRelease!.tagName,
                  onDismiss: widget.controller.dismissUpdateNotification,
                  onInstall: _downloadLatestApk,
                ),
              Expanded(child: _buildBody(state)),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadLatestApk() async {
    var progress = 0.0;
    bool finished = false;
    void Function(void Function())? dialogSetState;

    void updateProgress(int received, int total) {
      if (total <= 0) return;
      final newProgress = received / total;
      if (newProgress == progress) return;
      progress = newProgress;
      if (!finished) {
        dialogSetState?.call(() {});
      }
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            dialogSetState = setState;
            return AlertDialog(
              title: const Text('Downloading update'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Downloading the latest APK...'),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 8),
                  Text('${(progress * 100).toStringAsFixed(0)}%'),
                ],
              ),
            );
          },
        );
      },
    );

    final path = await widget.controller.downloadLatestApk(
      onProgress: updateProgress,
    );

    finished = true;
    if (!mounted) return;
    Navigator.of(context).pop();

    if (path != null) {
      await _installDownloadedApk(path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Update download failed.')),
      );
    }
  }

  Future<void> _installDownloadedApk(String path) async {
    final shouldInstall = await _showInstallUpdateDialog();
    if (!shouldInstall || !mounted) return;

    final installerOpened = await _openInstallerWithPermissionHandling(path);

    if (!installerOpened || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        duration: Duration(seconds: 8),
        content: Text(
          'Installer opened. If Android says "App non installata", remove the old app once and install this version again.',
        ),
      ),
    );
  }

  Future<bool> _showInstallUpdateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Install update'),
          content: const Text(
            'The APK is ready. Android will now open the installer.\n\n'
            'If Android asks for permission to install from this source, allow it and the installer will reopen automatically.\n\n'
            'If Android later shows "App non installata", the version already on the phone was signed with a different key: uninstall it once, then install this APK.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Install update'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<bool> _openInstallerWithPermissionHandling(
    String path, {
    bool allowPermissionRetry = true,
  }) async {
    final canInstall = await ApkInstallService.canRequestPackageInstalls();
    if (!canInstall) {
      if (!allowPermissionRetry || !mounted) return false;

      final granted = await _requestInstallPermission();
      if (!granted || !mounted) return false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Permission enabled, reopening installer...')),
      );
      return _openInstallerWithPermissionHandling(
        path,
        allowPermissionRetry: false,
      );
    }

    final result = await OpenFilex.open(path);
    if (result.type == ResultType.done) {
      return true;
    }

    final message = result.message.toLowerCase();
    if (allowPermissionRetry && _looksLikePermissionIssue(message)) {
      final granted = await _requestInstallPermission();
      if (!granted || !mounted) return false;

      return _openInstallerWithPermissionHandling(
        path,
        allowPermissionRetry: false,
      );
    }

    if (!mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        content: Text(
          _installerErrorMessage(result.message),
        ),
      ),
    );
    return false;
  }

  Future<bool> _requestInstallPermission() async {
    final wantsSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Allow app installs'),
          content: const Text(
            'Android is blocking the installer because installs from this app are not allowed yet. Open settings, enable the permission for this app, then come back here.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Open settings'),
            ),
          ],
        );
      },
    );

    if (wantsSettings != true) return false;

    final granted = await ApkInstallService.requestPackageInstallPermission();
    if (!mounted) return granted;

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 7),
          content: Text(
            'Install permission is still disabled. Enable it in Android settings to continue.',
          ),
        ),
      );
    }

    return granted;
  }

  bool _looksLikePermissionIssue(String message) {
    return message.contains('permission') ||
        message.contains('denied') ||
        message.contains('unknown source') ||
        message.contains('security');
  }

  String _installerErrorMessage(String? rawMessage) {
    final message = (rawMessage ?? '').trim();
    final normalized = message.toLowerCase();

    if (_looksLikePermissionIssue(normalized)) {
      return 'Android blocked the installer permission. Enable installs from this source in settings, then try again.';
    }

    return 'Could not open the installer. If Android later reports "App non installata", uninstall the old app once and retry. ${message.isEmpty ? '' : 'Details: $message'}'
        .trim();
  }

  Future<void> _checkUpdatesManually() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Checking for updates...')),
    );
    final hasUpdate = await widget.controller.checkForUpdate();
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    if (hasUpdate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Update available! Check the notification above.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on the latest version.')),
      );
    }
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
              ChartRangeSelector(
                state: state,
                onRangeSelected: widget.controller.setChartRange,
              ),
              const SizedBox(height: 6),
              ChartStatsRow(state: state),
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
        ChartRangeSelector(
          state: state,
          onRangeSelected: widget.controller.setChartRange,
        ),
        const SizedBox(height: 6),
        ChartStatsRow(state: state),
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
}
