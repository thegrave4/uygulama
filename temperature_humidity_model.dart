import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TemperatureHumidityData {
  final double temperature;
  final double humidity;
  final bool gasDetected; // Yeni eklenen alan
  final DateTime timestamp;

  TemperatureHumidityData({
    required this.temperature,
    required this.humidity,
    this.gasDetected = false, // Varsayılan değer
    required this.timestamp,
  });

  factory TemperatureHumidityData.fromJson(Map<String, dynamic> json) {
    return TemperatureHumidityData(
      temperature: json['temperature'].toDouble(),
      humidity: json['humidity'].toDouble(),
      gasDetected: json['gasDetected'] ?? false, // Yeni alan
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'temperature': temperature,
      'humidity': humidity,
      'gasDetected': gasDetected, // Yeni alan
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

class TemperatureHumidityModel extends ChangeNotifier {
  double _currentTemperature = 0.0;
  double _currentHumidity = 0.0;
  bool _currentGasDetected = false; // Yeni eklenen alan
  List<TemperatureHumidityData> _historicalData = [];
  String _raspberryPiIp = '';
  String _wifiSsid = '';
  String _wifiPassword = '';

  // Getters
  double get currentTemperature => _currentTemperature;
  double get currentHumidity => _currentHumidity;
  bool get currentGasDetected => _currentGasDetected; // Yeni getter
  List<TemperatureHumidityData> get historicalData => _historicalData;
  String get raspberryPiIp => _raspberryPiIp;
  String get wifiSsid => _wifiSsid;
  String get wifiPassword => _wifiPassword;

  TemperatureHumidityModel() {
    _loadSettings();
    _loadHistoricalData();
  }

  // Load saved settings from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _raspberryPiIp = prefs.getString('raspberryPiIp') ?? '';
    _wifiSsid = prefs.getString('wifiSsid') ?? '';
    _wifiPassword = prefs.getString('wifiPassword') ?? '';
    notifyListeners();
  }

  // Save settings to SharedPreferences
  Future<void> saveSettings({
    String? raspberryPiIp,
    String? wifiSsid,
    String? wifiPassword,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (raspberryPiIp != null) {
      _raspberryPiIp = raspberryPiIp;
      await prefs.setString('raspberryPiIp', raspberryPiIp);
    }

    if (wifiSsid != null) {
      _wifiSsid = wifiSsid;
      await prefs.setString('wifiSsid', wifiSsid);
    }

    if (wifiPassword != null) {
      _wifiPassword = wifiPassword;
      await prefs.setString('wifiPassword', wifiPassword);
    }

    notifyListeners();
  }

  // Load historical data from SharedPreferences
  Future<void> _loadHistoricalData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString('historicalData');

    if (dataString != null) {
      final List<dynamic> jsonData = jsonDecode(dataString);
      _historicalData =
          jsonData
              .map((item) => TemperatureHumidityData.fromJson(item))
              .toList();

      if (_historicalData.isNotEmpty) {
        final latestData = _historicalData.last;
        _currentTemperature = latestData.temperature;
        _currentHumidity = latestData.humidity;
        _currentGasDetected = latestData.gasDetected; // Yeni alan
      }

      notifyListeners();
    }
  }

  // Save historical data to SharedPreferences
  Future<void> _saveHistoricalData() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = _historicalData.map((data) => data.toJson()).toList();
    await prefs.setString('historicalData', jsonEncode(jsonData));
  }

  // Update current temperature and humidity
  void updateCurrentData(
    double temperature,
    double humidity, {
    bool gasDetected = false,
  }) {
    _currentTemperature = temperature;
    _currentHumidity = humidity;
    _currentGasDetected = gasDetected; // Yeni alan

    // Add to historical data
    final newData = TemperatureHumidityData(
      temperature: temperature,
      humidity: humidity,
      gasDetected: gasDetected, // Yeni alan
      timestamp: DateTime.now(),
    );

    _historicalData.add(newData);

    // Limit historical data to last 7 days
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    _historicalData =
        _historicalData
            .where((data) => data.timestamp.isAfter(oneWeekAgo))
            .toList();

    _saveHistoricalData();
    notifyListeners();
  }

  // Fetch data from API
  Future<void> fetchDataFromApi() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://172.16.152.197:5136/Api/SensorApi/GetLatestSensorData',
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        if (jsonData.isNotEmpty) {
          // En son veri ile güncelle
          final latestData = jsonData[0];
          updateCurrentData(
            latestData['temperature'].toDouble(),
            latestData['humidity'].toDouble(),
            gasDetected: latestData['gasDetected'] ?? false,
          );

          // Tüm verileri tarihçeye ekle
          _historicalData.clear(); // Önceki verileri temizle

          for (var data in jsonData) {
            _historicalData.add(
              TemperatureHumidityData(
                temperature: data['temperature'].toDouble(),
                humidity: data['humidity'].toDouble(),
                gasDetected: data['gasDetected'] ?? false,
                timestamp: DateTime.parse(data['timestamp']),
              ),
            );
          }

          // Limit historical data to last 7 days
          final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
          _historicalData =
              _historicalData
                  .where((data) => data.timestamp.isAfter(oneWeekAgo))
                  .toList();

          _saveHistoricalData();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('API veri çekme hatası: $e');
    }
  }

  // API'den veri almak için yeni fonksiyon
  Future<void> fetchDataFromRaspberryPi() async {
    // API URL kontrolü
    await fetchDataFromApi();
  }

  // Get daily average temperature data for chart
  List<Map<String, dynamic>> getDailyAverageTemperature() {
    final Map<String, List<double>> dailyTemperatures = {};

    for (var data in _historicalData) {
      final day =
          '${data.timestamp.year}-${data.timestamp.month.toString().padLeft(2, '0')}-${data.timestamp.day.toString().padLeft(2, '0')}';

      if (!dailyTemperatures.containsKey(day)) {
        dailyTemperatures[day] = [];
      }

      dailyTemperatures[day]!.add(data.temperature);
    }

    return dailyTemperatures.entries.map((entry) {
      final sum = entry.value.reduce((a, b) => a + b);
      final average = sum / entry.value.length;

      return {'day': entry.key, 'average': average};
    }).toList();
  }

  // Get daily average humidity data for chart
  List<Map<String, dynamic>> getDailyAverageHumidity() {
    final Map<String, List<double>> dailyHumidity = {};

    for (var data in _historicalData) {
      final day =
          '${data.timestamp.year}-${data.timestamp.month.toString().padLeft(2, '0')}-${data.timestamp.day.toString().padLeft(2, '0')}';

      if (!dailyHumidity.containsKey(day)) {
        dailyHumidity[day] = [];
      }

      dailyHumidity[day]!.add(data.humidity);
    }

    return dailyHumidity.entries.map((entry) {
      final sum = entry.value.reduce((a, b) => a + b);
      final average = sum / entry.value.length;

      return {'day': entry.key, 'average': average};
    }).toList();
  }
}
