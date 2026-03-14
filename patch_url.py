import re

with open('lib/screens/energy_monitor_screen.dart', 'r') as f:
    text = f.read()

old_func = """    void _openReleaseLink(dynamic release) {
      // For now, show a snackbar. In production, use url_launcher to open GitHub releases
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Visit GitHub releases for version ${release.tagName}'),
          action: SnackBarAction(label: 'OK', onPressed: () {}),
        ),
      );
    }"""

new_func = """    Future<void> _openReleaseLink(dynamic release) async {
      final url = Uri.parse('https://github.com/Fabbro96/solar_power_manager/releases/latest');
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the release link')),
        );
      }
    }"""

if old_func in text:
    text = text.replace(old_func, new_func)
    with open('lib/screens/energy_monitor_screen.dart', 'w') as f:
        f.write(text)
    print("Replaced successfully")
else:
    print("Function not found exactly as expected. Please check.")
