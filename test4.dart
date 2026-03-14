import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://github.com/Fabbro96/solar_power_manager/releases/download/stable/solar-power-manager-1.0.0--build-0-arm64-v8a.apk'\;
  final uri = Uri.parse(url);
  final request = http.Request('GET', uri);
  final response = await http.Client().send(request);
  print(response.statusCode);
}
