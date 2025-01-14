import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeRight,
    DeviceOrientation.landscapeLeft,
  ]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EnergyMonitor(),
      routes: {
        '/daily': (context) => DailyDataScreen(),
      },
    );
  }
}

class EnergyMonitor extends StatefulWidget {
  const EnergyMonitor({super.key});

  @override
  _EnergyMonitorState createState() => _EnergyMonitorState();
}

class _EnergyMonitorState extends State<EnergyMonitor> {
  String todaysEnergy = "Loading...";
  String powerNow = "Loading...";
  String lastUpdate = "-";
  final String url = "http://192.168.1.16/monitor.htm";
  final String username = "admin";
  final String password = "admin";
  List<FlSpot> powerData = [];
  final int maxDataPoints = 50;
  int xValue = 0;
  Timer? _fetchDataTimer;
  Timer? _updateDataTimer;
  Timer? _updateGraphTimer;
  Timer? _saveDataTimer;
  double? latestPowerValue;
  String appBarTitle = "Solar Monitor";
  String googleConnectionStatus = "Checking..."; // Stato connessione a Google

  @override
  void initState() {
    super.initState();
    _testGoogleConnection(); // Testa la connessione a Google all'avvio
    _fetchData();
    _fetchDataTimer =
        Timer.periodic(Duration(minutes: 10), (timer) => _fetchData());
    _updateDataTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _fetchData();
    });
    _updateGraphTimer = Timer.periodic(Duration(minutes: 1), (timer) {
      if (latestPowerValue != null) {
        _updateChartData(latestPowerValue!);
      }
    });
    _saveDataTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _saveDataToCsv();
    });
  }

  @override
  void dispose() {
    _fetchDataTimer?.cancel();
    _updateDataTimer?.cancel();
    _updateGraphTimer?.cancel();
    _saveDataTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    _testGoogleConnection();
    try {
      final credentials = '$username:$password';
      final encodedCredentials = base64Encode(utf8.encode(credentials));
      final headers = {
        'Authorization': 'Basic $encodedCredentials',
      };

      // Usa http.get invece di dio.get
      final response = await http
          .get(Uri.parse(url), headers: headers)
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        final document = parse(response.body);
        setState(() {
          todaysEnergy = _findValue(document, "Today's Energy");
          powerNow = _findValue(document, "Power Now");
          lastUpdate = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
          latestPowerValue = double.tryParse(cleanValue(powerNow));
          appBarTitle = "Solar Monitor: connected"; // Imposta stato "connesso"
        });
      } else {
        setState(() {
          todaysEnergy = "Error: ${response.statusCode}";
          powerNow = "Error: ${response.statusCode}";
          lastUpdate = "Error: ${response.statusCode}";
          latestPowerValue = null;
          appBarTitle =
              "Solar Monitor: error [${response.statusCode}]"; // Imposta stato "errore"
        });
      }
    } catch (e) {
      setState(() {
        todaysEnergy = "Error: Unable to fetch data";
        powerNow = "Error: Unable to fetch data";
        lastUpdate = "Error: Unable to fetch data";
        latestPowerValue = null;
        appBarTitle =
            "Solar Monitor: error [${e.toString()}]"; // Imposta stato "errore"
      });
    }
  }

  String cleanValue(String value) {
    return value.replaceAll(RegExp(r'[^0-9.]'), '');
  }

  String _findValue(document, String keyword) {
    final elements = document.getElementsByTagName('td');
    for (var i = 0; i < elements.length - 1; i++) {
      if (elements[i].text.trim() == '$keyword:') {
        return elements[i + 1].text.trim();
      }
    }
    return "Not found";
  }

  void _updateChartData(double powerValue) {
    setState(() {
      powerData.add(FlSpot(xValue.toDouble(), powerValue));
      if (powerData.length > maxDataPoints) {
        powerData.removeAt(0);
      }
      xValue++;
    });
  }

  // Funzione per determinare l'intervallo dell'asse Y
  double _getYAxisInterval(List<FlSpot> data) {
    if (data.isEmpty) return 100; // Valore predefinito

    double maxPower =
        data.map((spot) => spot.y).reduce((a, b) => a > b ? a : b);

    if (maxPower < 500) return 100;
    if (maxPower < 1000) return 200;
    if (maxPower < 2000) return 500;
    if (maxPower < 5000) return 1000;
    return 2000;
  }

  Future<void> _testGoogleConnection() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));
      if (response.statusCode == 200) {
        setState(() {
          googleConnectionStatus = "Google: connected";
        });
      } else {
        setState(() {
          googleConnectionStatus = "Google: error [${response.statusCode}]";
        });
      }
    } catch (e) {
      setState(() {
        googleConnectionStatus = "Google: error [${e.toString()}]";
      });
    }
  }

  // Funzione per salvare i dati in un file CSV, gestendo l'append
  Future<void> _saveDataToCsv() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/solar_data.csv';
    final file = File(filePath);

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
    final power = latestPowerValue != null ? cleanValue(powerNow) : "N/A";
    final energy = todaysEnergy;

    // Controlla se il file esiste e se è vuoto, se sì, aggiungi l'intestazione
    String header = "";
    if (!file.existsSync() || file.lengthSync() == 0) {
      header = "Date and Time,Solar Power (W),Daily Energy (kWh)\n";
    }

    // Crea la riga CSV manualmente (con la formattazione di base)
    String row = '$formattedDate,$power,$energy\n';

    try {
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
      // Scrivi l'intestazione (se presente) e la riga nel file in modalità append
      await file.writeAsString(header + row, mode: FileMode.append);

      print("Dati salvati in: $filePath");
    } on FileSystemException catch (e) {
      // Gestisci specificamente gli errori di accesso al file system
      print("Errore di I/O durante il salvataggio del file CSV: $e");
    } catch (e) {
      print("Errore durante il salvataggio del file CSV: $e");
      // Gestisci altri errori generici
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: Text(
          appBarTitle, // Usa la variabile appBarTitle per il titolo
          style: TextStyle(
            color: Color.fromRGBO(100, 200, 255, 1),
            fontSize: 20,
            fontWeight: FontWeight.w300,
          ),
        ),
        actions: <Widget>[
          // Testo "Auto-refresh every 10 minutes"
          Center(
            child: Padding(
              padding: EdgeInsets.only(
                  right: 10.0), // Aggiungi un po' di spazio a destra
              child: GestureDetector(
                onTap: _fetchData,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.refresh,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Auto-refresh every 10 minutes',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Bottone "View Daily Data"
          Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/daily');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
              ),
              child: Text('View Daily Data',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Last update: $lastUpdate',
                      style: TextStyle(
                        color: Color.fromRGBO(180, 180, 255, 1),
                        fontSize: 14,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                  //GRAFICO
                  Container(
                    height: MediaQuery.of(context).size.height * 0.6,
                    padding: EdgeInsets.only(right: 20, top: 10),
                    child: LineChart(
                      LineChartData(
                        backgroundColor: Colors.black,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          drawHorizontalLine: true,
                          verticalInterval: (powerData.isNotEmpty &&
                                  powerData.length > 1 &&
                                  powerData.last.x - powerData.first.x != 0)
                              ? (powerData.last.x - powerData.first.x) / 6
                              : 10,
                          horizontalInterval: _getYAxisInterval(powerData),
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Color.fromRGBO(100, 150, 200, 0.5),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                              color: Color.fromRGBO(100, 150, 200, 0.5),
                              strokeWidth: 1,
                              dashArray: [5, 5],
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 28,
                              interval: (powerData.isNotEmpty &&
                                      powerData.length > 1 &&
                                      powerData.last.x - powerData.first.x != 0)
                                  ? (powerData.last.x - powerData.first.x) / 6
                                  : 10,
                              getTitlesWidget: (value, meta) {
                                if (powerData.isNotEmpty) {
                                  final dateTime = DateTime.now().subtract(
                                      Duration(
                                          seconds: (powerData.last.x - value)
                                                  .toInt() *
                                              5));
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      DateFormat('HH:mm').format(dateTime),
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                } else {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(""),
                                  );
                                }
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: _getYAxisInterval(powerData),
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                if (powerData.isNotEmpty) {
                                  return Text(
                                    '${value.toInt()}W',
                                    style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                    ),
                                  );
                                } else {
                                  return Text("");
                                }
                              },
                            ),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(
                            color: Colors.white12,
                            width: 1,
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: powerData,
                            isCurved: true,
                            curveSmoothness: 0.4,
                            color: Color.fromRGBO(0, 255, 255, 1),
                            barWidth: 3,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Color.fromRGBO(0, 255, 255, 0.2),
                              gradient: LinearGradient(
                                colors: [
                                  Color.fromRGBO(0, 255, 255, 0.7),
                                  Color.fromRGBO(0, 255, 255, 0.01),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 20),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Power',
                          style: TextStyle(
                            color: Color.fromRGBO(150, 180, 255, 1),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          powerNow,
                          style: TextStyle(
                            color: Color.fromRGBO(100, 200, 255, 1),
                            fontSize: 28,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Today',
                          style: TextStyle(
                            color: Color.fromRGBO(150, 180, 255, 1),
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          todaysEnergy,
                          style: TextStyle(
                            color: Color.fromRGBO(100, 200, 255, 1),
                            fontSize: 28,
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          googleConnectionStatus,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DailyDataScreen extends StatefulWidget {
  const DailyDataScreen({super.key});

  @override
  _DailyDataScreenState createState() => _DailyDataScreenState();
}

class _DailyDataScreenState extends State<DailyDataScreen> {
  Map<String, dynamic> dailyData = {};
  String? selectedDay;

  @override
  void initState() {
    super.initState();
    _loadDailyData();
  }

  Future<void> _loadDailyData() async {
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/solar_data.csv';
    final file = File(filePath);

    if (file.existsSync()) {
      final lines = await file.readAsLines();

      // Inizializza dailyData come un Map vuoto
      setState(() {
        dailyData = {};
      });

      for (var i = 1; i < lines.length; i++) {
        // Inizia da 1 per saltare l'intestazione
        final parts = lines[i].split(',');
        if (parts.length >= 3) {
          final date = parts[0];
          final power = parts[1];
          final energy = parts[2];

          // Estrai il giorno dal timestamp
          final day = date.split(' ')[0];

          // Aggiungi i dati al giorno corrispondente
          if (!dailyData.containsKey(day)) {
            dailyData[day] = [];
          }
          dailyData[day]
              .add({'timestamp': date, 'power': power, 'energy': energy});
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Daily Data",
          style: TextStyle(color: Color.fromRGBO(100, 200, 255, 1)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color.fromRGBO(100, 200, 255, 1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: dailyData.length,
              itemBuilder: (context, index) {
                String day = dailyData.keys.elementAt(index);
                // Ottieni l'ultimo valore di 'energy' per questo giorno
                var lastEntry = dailyData[day].last;
                String energyValue = lastEntry['energy'] ?? 'N/A';

                return ListTile(
                  title: Text(
                    day,
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    "Energy: $energyValue",
                    style: TextStyle(color: Colors.grey),
                  ),
                  onTap: () {
                    setState(() {
                      selectedDay = day;
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            DayDetailsScreen(dayData: dailyData[day], day: day),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (selectedDay != null)
            Expanded(
              child: DayDetailsScreen(
                  dayData: dailyData[selectedDay], day: selectedDay),
            ),
        ],
      ),
    );
  }
}

class DayDetailsScreen extends StatelessWidget {
  final List<dynamic> dayData;
  final String? day;

  const DayDetailsScreen({super.key, required this.dayData, this.day});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          day ?? 'Dettagli del giorno',
          style: TextStyle(color: Color.fromRGBO(100, 200, 255, 1)),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color.fromRGBO(100, 200, 255, 1)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        itemCount: dayData.length,
        itemBuilder: (context, index) {
          var entry = dayData[index];
          return ListTile(
            title: Text(
              "Power: ${entry['power']}",
              style: TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              "Time: ${entry['timestamp']}",
              style: TextStyle(color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}
