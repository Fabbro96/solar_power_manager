import 'package:http/http.dart' as http;

void main() async {
  try {
    final uri = Uri.parse('https://github.com/Fabbro96/solar_power_manager/releases/download/v2.1/solar-power-manager-2.1.0-arm64-v8a.apk'); // fake url maybe
    final response = await http.get(Uri.parse('https://github.com/Fabbro96/solar_power_manager/releases/latest'));
    print(response.statusCode);
  } catch (e) {
    print(e);
  }
}
