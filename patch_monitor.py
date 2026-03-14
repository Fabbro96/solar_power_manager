import re

with open('lib/screens/energy_monitor_screen.dart', 'r') as f:
    text = f.read()

# Replace import
if "import '../theme/app_theme.dart';" in text:
    text = text.replace(
        "import '../theme/app_theme.dart';",
        "import '../theme/app_theme.dart';\nimport 'settings_screen.dart';"
    )

# Replace the whole _showSettingsDialog with Navigation
settings_dialog_regex = r"Future<void> _showSettingsDialog\(BuildContext context\) async \{.*?\s*c4\.dispose\(\);\s*f1\.dispose\(\);\s*f2\.dispose\(\);\s*f3\.dispose\(\);\s*f4\.dispose\(\);\s*\}"

import re
text = re.sub(settings_dialog_regex, """Future<void> _showSettingsDialog(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(
          controller: widget.controller,
          onSettingsSaved: widget.onSettingsSaved,
        ),
      ),
    );
  }""", text, flags=re.DOTALL)

with open('lib/screens/energy_monitor_screen.dart', 'w') as f:
    f.write(text)
