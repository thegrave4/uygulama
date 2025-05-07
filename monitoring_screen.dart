import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/temperature_humidity_model.dart';

class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({super.key});

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  Timer? _refreshTimer;
  bool _isLoading = true;
  String _errorMessage = '';
  List<DailyAverageData> _dailyAverages = [];
  DateTime _lastUpdated = DateTime.now(); // Son güncelleme zamanı

  @override
  void initState() {
    super.initState();
    _fetchCurrentData();
    _fetchHistoricalData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchCurrentData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Fetch current sensor data
  Future<void> _fetchCurrentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse(
          'http://192.168.29.139:5136/Api/SensorApi/GetLatestSensorData',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        // Process data for model
        if (jsonData.isNotEmpty) {
          final model = Provider.of<TemperatureHumidityModel>(
            context,
            listen: false,
          );

          // Process all records
          for (var item in jsonData) {
            model.updateCurrentData(
              item['temperature'].toDouble(),
              item['humidity'].toDouble(),
              gasDetected: item['gasDetected'] ?? false,
            );
          }

          // Update last updated timestamp
          setState(() {
            _lastUpdated = DateTime.now();
          });
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Veri alınamadı: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Hata oluştu: $e';
        _isLoading = false;
      });
      debugPrint('API veri çekme hatası: $e');
    }
  }

  // Fetch historical data and calculate daily averages
  Future<void> _fetchHistoricalData() async {
    try {
      final response = await http.get(
        Uri.parse('http://192.168.29.139:5136/Api/SensorApi/GetOldSensorData'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        // Group data by day and calculate averages
        final Map<String, List<Map<String, dynamic>>> dataByDay = {};

        for (var item in jsonData) {
          final timestamp = DateTime.parse(item['timestamp']);
          final day =
              '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

          if (!dataByDay.containsKey(day)) {
            dataByDay[day] = [];
          }

          dataByDay[day]!.add(item);
        }

        // Calculate daily averages
        final List<DailyAverageData> dailyAverages = [];

        dataByDay.forEach((day, records) {
          double totalTemp = 0;
          double totalHumidity = 0;
          bool anyGasDetected = false;

          for (var record in records) {
            totalTemp += record['temperature'].toDouble();
            totalHumidity += record['humidity'].toDouble();
            anyGasDetected = anyGasDetected || (record['gasDetected'] ?? false);
          }

          final avgTemp = totalTemp / records.length;
          final avgHumidity = totalHumidity / records.length;

          dailyAverages.add(
            DailyAverageData(
              date: DateTime.parse(day),
              averageTemperature: avgTemp,
              averageHumidity: avgHumidity,
              gasDetected: anyGasDetected,
            ),
          );
        });

        // Sort by date (newest first)
        dailyAverages.sort((a, b) => b.date.compareTo(a.date));

        setState(() {
          _dailyAverages = dailyAverages;
        });
      }
    } catch (e) {
      debugPrint('Tarihçe veri çekme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TemperatureHumidityModel>(
      builder: (context, model, child) {
        return Container(
          color: const Color(0xFF383B39),
          padding: const EdgeInsets.all(16.0),
          child:
              _isLoading
                  ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFFB2BEB5)),
                  )
                  : _errorMessage.isNotEmpty
                  ? Center(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildDataField(
                              'Sıcaklık:',
                              '${model.currentTemperature.toStringAsFixed(1)}°C',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDataField(
                              'Nem:',
                              '${model.currentHumidity.toStringAsFixed(1)}%',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDataField(
                              'Gaz Algılandı:',
                              model.currentGasDetected ? 'Evet' : 'Hayır',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDataField(
                              'Son Güncelleme:',
                              _formatDateTime(_lastUpdated),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Tarihçe (Günlük Ortalamalar)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB2BEB5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildHistoryTable()),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildDataField(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFFB2BEB5),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, color: Color(0xFFB2BEB5)),
        ),
      ],
    );
  }

  Widget _buildHistoryTable() {
    if (_dailyAverages.isEmpty) {
      return const Center(
        child: Text('Veri yok', style: TextStyle(color: Color(0xFFB2BEB5))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFB2BEB5), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SingleChildScrollView(
        child: Table(
          border: TableBorder.all(color: const Color(0xFF555755), width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(1.8),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header row
            TableRow(
              decoration: const BoxDecoration(color: Color(0xFFee3a1f)),
              children: [
                _buildTableHeaderCell('Ort. Sıcaklık (°C)'),
                _buildTableHeaderCell('Ort. Nem (%)'),
                _buildTableHeaderCell('Gaz Algılandı'),
                _buildTableHeaderCell('Tarih'),
              ],
            ),
            // Data rows
            ..._dailyAverages.map((data) {
              return TableRow(
                decoration: BoxDecoration(
                  color:
                      _dailyAverages.indexOf(data) % 2 == 0
                          ? const Color(0xFF2A2C2A)
                          : const Color(0xFF222422),
                ),
                children: [
                  _buildTableCell(data.averageTemperature.toStringAsFixed(1)),
                  _buildTableCell(data.averageHumidity.toStringAsFixed(1)),
                  _buildTableCell(data.gasDetected ? 'Evet' : 'Hayır'),
                  _buildTableCell(_formatDate(data.date)),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildTableCell(
    String text, {
    Color? textColor,
    FontWeight? fontWeight,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor ?? const Color(0xFFB2BEB5),
          fontWeight: fontWeight ?? FontWeight.normal,
          fontSize: 14,
        ),
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    // Format: dd/MM/yyyy
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year}';
  }

  String _formatDateTime(DateTime dateTime) {
    // Format: dd/MM/yyyy HH:mm:ss
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}';
  }
}

// Class to hold daily average data
class DailyAverageData {
  final DateTime date;
  final double averageTemperature;
  final double averageHumidity;
  final bool gasDetected;

  DailyAverageData({
    required this.date,
    required this.averageTemperature,
    required this.averageHumidity,
    required this.gasDetected,
  });
}
