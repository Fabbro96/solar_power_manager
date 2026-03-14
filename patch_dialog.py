import re

with open('lib/screens/energy_monitor_screen.dart', 'r') as f:
    text = f.read()

# 1. Rename onIpSaved to onSettingsSaved
text = text.replace(
    'final Future<void> Function(String)? onIpSaved;',
    'final Future<void> Function(String, String, String)? onSettingsSaved;'
)
text = text.replace(
    'this.onIpSaved,',
    'this.onSettingsSaved,'
)
text = text.replace(
    'await widget.onIpSaved?.call(ip);',
    'await widget.onSettingsSaved?.call(ip, userCtrl.text.trim(), passCtrl.text.trim());'
)

# 2. _showIpDialog to _showSettingsDialog
text = text.replace('_showIpDialog(context)', '_showSettingsDialog(context)')
text = text.replace('Future<void> _showIpDialog(BuildContext context) async {', 'Future<void> _showSettingsDialog(BuildContext context) async {\n    final userCtrl = TextEditingController(text: widget.controller.currentUsername);\n    final passCtrl = TextEditingController(text: widget.controller.currentPassword);')

# 3. probeInverterIp to probeInverterConfig
text = text.replace(
    'await widget.controller.probeInverterIp(ip);',
    'await widget.controller.probeInverterConfig(ip: ip, username: userCtrl.text.trim(), password: passCtrl.text.trim());'
)

# 4. updateInverterIp to updateInverterConfig
text = text.replace(
    'await widget.controller.updateInverterIp(ip);',
    'await widget.controller.updateInverterConfig(ip: ip, username: userCtrl.text.trim(), password: passCtrl.text.trim());'
)

# 5. Add user/pass fields in dialog
auth_fields = """
              const SizedBox(height: 14),
              const Text('Inverter Credentials', style: TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 8),
              TextField(
                controller: userCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Password',
                  labelStyle: TextStyle(color: Colors.white54),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
                ),
              ),
              const SizedBox(height: 14),
"""
text = text.replace(
    'const SizedBox(height: 10),\n              Row(\n                children: [',
    auth_fields + 'const SizedBox(height: 10),\n              Row(\n                children: ['
)

# 6. Dispose controllers
text = text.replace(
    '    c1.dispose();',
    '    userCtrl.dispose();\n    passCtrl.dispose();\n    c1.dispose();'
)

# Title change
text = text.replace("'Inverter IP address',", "'Inverter Settings',")

with open('lib/screens/energy_monitor_screen.dart', 'w') as f:
    f.write(text)
