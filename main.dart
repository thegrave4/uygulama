import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Screens
import 'screens/settings_screen.dart';
import 'screens/monitoring_screen.dart';

// Models and services
import 'models/temperature_humidity_model.dart';
import 'services/bluetooth_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // RaspBluetoothService'i bir değişken olarak oluştur
    final bluetoothService = RaspBluetoothService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TemperatureHumidityModel()),
        // RaspBluetoothService bir ChangeNotifier olmadığı için Provider kullanıyoruz
        Provider<RaspBluetoothService>.value(value: bluetoothService),
      ],
      child: MaterialApp(
        title: 'RaspTemp',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const RaspTempApp(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

class RaspTempApp extends StatefulWidget {
  const RaspTempApp({super.key});

  @override
  State<RaspTempApp> createState() => _RaspTempAppState();
}

class _RaspTempAppState extends State<RaspTempApp>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes to update the UI
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    // Bluetooth servisini temizleme işlemi
    final bluetoothService = Provider.of<RaspBluetoothService>(
      context,
      listen: false,
    );
    // Eğer dispose metodu varsa çağır
    if (bluetoothService is RaspBluetoothService) {
      // Burada bluetoothService.dispose() gibi bir metod çağrılabilir
      // ancak mevcut implementasyonda bu metod yoksa hata verebilir
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: const [SettingsScreen(), MonitoringScreen()],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF383B39),
          border: Border(top: BorderSide(color: Color(0xFFB2BEB5), width: 2.0)),
        ),
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: Icon(
                Icons.settings,
                color:
                    _tabController.index == 0
                        ? const Color(0xFFa64242)
                        : const Color(0xFFB2BEB5),
              ),
              child: Text(
                'Ayarla',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      _tabController.index == 0
                          ? const Color(0xFFa64242)
                          : const Color(0xFFB2BEB5),
                ),
              ),
            ),
            Tab(
              icon: Icon(
                Icons.monitor,
                color:
                    _tabController.index == 1
                        ? const Color(0xFFa64242)
                        : const Color(0xFFB2BEB5),
              ),
              child: Text(
                'İzleme',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color:
                      _tabController.index == 1
                          ? const Color(0xFFa64242)
                          : const Color(0xFFB2BEB5),
                ),
              ),
            ),
          ],
          onTap: (index) {
            setState(() {});
          },
          indicatorColor: Colors.transparent,
        ),
      ),
    );
  }
}
