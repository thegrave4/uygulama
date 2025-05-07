import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/temperature_humidity_model.dart';
import '../services/bluetooth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  String? _currentWifiSSID;
  bool _isLoading = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    _getCurrentWifiInfo();
    _checkBluetoothConnection();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentWifiInfo() async {
    try {
      final info = NetworkInfo();
      final ssid = await info.getWifiName();
      if (ssid != null) {
        setState(() {
          _currentWifiSSID = ssid.replaceAll('"', ''); // Remove quotes if present
        });
      }
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
    }
  }

  Future<void> _checkBluetoothConnection() async {
    final bluetoothService = Provider.of<RaspBluetoothService>(
      context,
      listen: false,
    );

    setState(() => _isLoading = true);
    bool initialized = await bluetoothService.initBluetooth(context);

    if (!initialized) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth başlatılamadı')),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isConnected = bluetoothService.isConnected;
        _connectedDevice = bluetoothService.connectedDevice;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendWifiCredentials() async {
    if (_currentWifiSSID == null || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen WiFi şifresini girin')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final bluetoothService = Provider.of<RaspBluetoothService>(
      context,
      listen: false,
    );

    try {
      final success = await bluetoothService.sendWifiCredentials(
        _currentWifiSSID!,
        _passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'WiFi bilgileri başarıyla gönderildi'
                  : 'WiFi bilgileri gönderilemedi',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bluetooth Status Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Bluetooth Durumu',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                _isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_disabled,
                                color: _isConnected ? Colors.blue : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _isConnected
                                      ? 'Bağlı: ${_connectedDevice?.name ?? "Bilinmeyen Cihaz"}'
                                      : 'Bağlı Değil',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // WiFi Configuration Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WiFi Yapılandırması',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Current WiFi Network
                          ListTile(
                            leading: const Icon(Icons.wifi),
                            title: const Text('Mevcut WiFi Ağı'),
                            subtitle: Text(_currentWifiSSID ?? 'Bağlı Değil'),
                            dense: true,
                          ),
                          const SizedBox(height: 16),
                          // Password Field
                          TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              labelText: 'WiFi Şifresi',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          // Send Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isConnected ? _sendWifiCredentials : null,
                              icon: const Icon(Icons.send),
                              label: const Text('WiFi Bilgilerini Gönder'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
