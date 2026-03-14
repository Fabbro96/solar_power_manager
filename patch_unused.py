import re

with open('lib/screens/energy_monitor_screen.dart', 'r') as f:
    text = f.read()

# Define patterns to match and remove the unused methods.
# using DOTALL is safer

p1 = r"  static List<String> _splitIpIntoOctets\(String ip\) \{.*?\n  \}"
p2 = r"  Widget _octetField\(\s*TextEditingController controller,\s*FocusNode focus,\s*FocusNode\? next,\s*StateSetter setDialogState,\s*\) \{.*?\n  \}"
p3 = r"  static bool _isValidIp\(String ip\) \{.*?\n  \}"

text = re.sub(p1, "", text, flags=re.DOTALL)
text = re.sub(p2, "", text, flags=re.DOTALL)
text = re.sub(p3, "", text, flags=re.DOTALL)

with open('lib/screens/energy_monitor_screen.dart', 'w') as f:
    f.write(text)
