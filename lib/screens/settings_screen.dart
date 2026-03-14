import 'package:flutter/material.dart';
import '../controllers/energy_controller.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final EnergyController controller;
  final Future<void> Function(String ip, String username, String password)?
      onSettingsSaved;

  const SettingsScreen({
    super.key,
    required this.controller,
    this.onSettingsSaved,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ipC1;
  late TextEditingController _ipC2;
  late TextEditingController _ipC3;
  late TextEditingController _ipC4;
  late FocusNode _f1;
  late FocusNode _f2;
  late FocusNode _f3;
  late FocusNode _f4;

  late TextEditingController _userCtrl;
  late TextEditingController _passCtrl;

  String? _errorText;
  String? _probeMessage;
  bool _probeOk = false;
  bool _isProbing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final currentIp = widget.controller.currentInverterIp;
    final parts = _splitIpIntoOctets(currentIp);

    _ipC1 = TextEditingController(text: parts[0]);
    _ipC2 = TextEditingController(text: parts[1]);
    _ipC3 = TextEditingController(text: parts[2]);
    _ipC4 = TextEditingController(text: parts[3]);

    _f1 = FocusNode();
    _f2 = FocusNode();
    _f3 = FocusNode();
    _f4 = FocusNode();

    _userCtrl = TextEditingController(text: widget.controller.currentUsername);
    _passCtrl = TextEditingController(text: widget.controller.currentPassword);
  }

  @override
  void dispose() {
    _ipC1.dispose();
    _ipC2.dispose();
    _ipC3.dispose();
    _ipC4.dispose();
    _f1.dispose();
    _f2.dispose();
    _f3.dispose();
    _f4.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  List<String> _splitIpIntoOctets(String ip) {
    final parts = ip.split('.');
    if (parts.length == 4) return parts;
    return ['192', '168', '1', '100'];
  }

  bool _isValidIp(String ip) {
    final exp = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$');
    final match = exp.firstMatch(ip);
    if (match == null) return false;
    for (int i = 1; i <= 4; i++) {
      final val = int.tryParse(match.group(i)!);
      if (val == null || val < 0 || val > 255) return false;
    }
    return true;
  }

  String _composeIp() =>
      '${_ipC1.text.trim()}.${_ipC2.text.trim()}.${_ipC3.text.trim()}.${_ipC4.text.trim()}';

  Widget _octetField(
      TextEditingController controller, FocusNode node, FocusNode? nextNode) {
    return TextFormField(
      controller: controller,
      focusNode: node,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 3,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onChanged: (val) {
        if (val.length == 3 && nextNode != null) {
          nextNode.requestFocus();
        }
      },
    );
  }

  Future<void> _runProbe() async {
    final ip = _composeIp();
    if (!_isValidIp(ip)) {
      setState(() {
        _errorText = 'Invalid IP address';
        _probeMessage = null;
        _probeOk = false;
      });
      return;
    }

    setState(() {
      _isProbing = true;
      _errorText = null;
      _probeMessage = null;
      _probeOk = false;
    });

    final result = await widget.controller.probeInverterConfig(
      ip: ip,
      username: _userCtrl.text.trim(),
      password: _passCtrl.text.trim(),
    );

    if (!mounted) return;

    setState(() {
      _isProbing = false;
      _probeMessage = result.message;
      _probeOk = result.success;
    });
  }

  Future<void> _saveSettings() async {
    final ip = _composeIp();
    if (!_isValidIp(ip)) {
      setState(() => _errorText = 'Invalid IP address');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    if (!_probeOk) {
      final probeResult = await widget.controller.probeInverterConfig(
        ip: ip,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;

      if (!probeResult.success) {
        setState(() {
          _isSaving = false;
          _probeMessage = probeResult.message;
          _probeOk = false;
        });
        return;
      }
    }

    try {
      await widget.controller.updateInverterConfig(
        ip: ip,
        username: _userCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      await widget.onSettingsSaved?.call(
        ip,
        _userCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Save failed: $e';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Inverter Settings',
            style: TextStyle(color: Colors.white70)),
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Network Configuration',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _octetField(_ipC1, _f1, _f2)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('.',
                      style: TextStyle(color: Colors.white70, fontSize: 24)),
                ),
                Expanded(child: _octetField(_ipC2, _f2, _f3)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('.',
                      style: TextStyle(color: Colors.white70, fontSize: 24)),
                ),
                Expanded(child: _octetField(_ipC3, _f3, _f4)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('.',
                      style: TextStyle(color: Colors.white70, fontSize: 24)),
                ),
                Expanded(child: _octetField(_ipC4, _f4, null)),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Authentication',
              style: TextStyle(
                  color: Colors.white54,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.person_outline, color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: const TextStyle(color: Colors.white54),
                prefixIcon:
                    const Icon(Icons.lock_outline, color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 32),
            if (_errorText != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(_errorText!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_probeMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_probeOk ? const Color(0xFF66E4A8) : Colors.orange)
                      .withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _probeOk
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      color: _probeOk ? const Color(0xFF66E4A8) : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _probeMessage!,
                        style: TextStyle(
                          color: _probeOk
                              ? const Color(0xFF66E4A8)
                              : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: _isProbing || _isSaving ? null : _runProbe,
                icon: _isProbing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(
                    _isProbing ? 'Testing Connection...' : 'Test Connection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black87),
                      )
                    : const Icon(Icons.save, color: Colors.black87),
                label: Text(
                  _isSaving ? 'Saving...' : 'Apply & Save',
                  style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
