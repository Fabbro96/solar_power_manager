import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

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
  }

  @override
  void dispose() {
    _fetchDataTimer?.cancel();
    _updateDataTimer?.cancel();
    _updateGraphTimer?.cancel();
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
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth > constraints.maxHeight) {
            // Layout orizzontale
            return Padding(
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
                          height: constraints.maxHeight * 0.6,
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
                                        powerData.last.x - powerData.first.x !=
                                            0)
                                    ? (powerData.last.x - powerData.first.x) / 6
                                    : 10,
                                horizontalInterval:
                                    _getYAxisInterval(powerData),
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
                                            powerData.last.x -
                                                    powerData.first.x !=
                                                0)
                                        ? (powerData.last.x -
                                                powerData.first.x) /
                                            6
                                        : 10,
                                    getTitlesWidget: (value, meta) {
                                      if (powerData.isNotEmpty) {
                                        // Usa i minuti solo se i dati coprono meno di un'ora, altrimenti usa le ore
                                        if (powerData.last.x -
                                                powerData.first.x <
                                            3600 / 5) {
                                          // Assumendo che un xValue rappresenti 5 secondi
                                          final dateTime = DateTime.now()
                                              .subtract(Duration(
                                                  seconds:
                                                      (powerData.last.x - value)
                                                              .toInt() *
                                                          5));
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(
                                              DateFormat('mm').format(dateTime),
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        } else {
                                          final dateTime = DateTime.now()
                                              .subtract(Duration(
                                                  seconds:
                                                      (powerData.last.x - value)
                                                              .toInt() *
                                                          5));
                                          return SideTitleWidget(
                                            axisSide: meta.axisSide,
                                            child: Text(
                                              DateFormat('HH:mm')
                                                  .format(dateTime),
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                            ),
                                          );
                                        }
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
                              IconButton(
                                icon: Icon(Icons.refresh,
                                    color: Color.fromRGBO(150, 180, 255, 1)),
                                onPressed: _fetchData,
                              ),
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
                      ],
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Layout verticale
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Row(
                    children: [
                      Expanded(
                        child: Container(
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
                      ),
                      Expanded(
                        child: Container(
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
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Expanded(
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 100,
                          verticalInterval: (powerData.isNotEmpty &&
                                  powerData.length > 1 &&
                                  powerData.last.x - powerData.first.x != 0)
                              ? (powerData.last.x - powerData.first.x) / 6
                              : 10,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Color.fromRGBO(100, 150, 200, 0.5),
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 100,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  '${value.toInt()}W',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                );
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
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: powerData,
                            isCurved: true,
                            color: Color.fromRGBO(0, 255, 255, 1),
                            barWidth: 2,
                            dotData: FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Color.fromRGBO(0, 255, 255, 0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Spacer(),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          googleConnectionStatus, // Mostra lo stato della connessione a Google
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.refresh,
                              color: Color.fromRGBO(150, 180, 255, 1)),
                          onPressed: _fetchData,
                        ),
                        Text(
                          'Auto-refresh every 10 minutes',
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}
