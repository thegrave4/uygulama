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
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _currentWifiSSID;
  bool _isLoading = false;
  bool _isScanning = false;
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;
  String _statusMessage = '';
  bool _useCurrentWifi = true;

  @override
  void initState() {
    super.initState();
    _getCurrentWifiInfo();
    _checkBluetoothConnection();
  }

  @override
  void dispose() {
    _ssidController.dispose();
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
          _ssidController.text = _currentWifiSSID ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
      setState(() {
        _statusMessage = 'WiFi bilgileri alınamadı';
      });
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
        setState(() {
          _statusMessage = 'Bluetooth başlatılamadı. Lütfen Bluetooth\'u açın.';
          _isLoading = false;
        });
      }
      return;
    }

    if (bluetoothService.isConnected && bluetoothService.connectedDevice != null) {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectedDevice = bluetoothService.connectedDevice;
          _statusMessage = '${_connectedDevice?.name ?? "Cihaz"} bağlı.';
          _isLoading = false;
        });
      }
    } else {
      // Eğer bağlı değilse, Raspberry Pi'yi aramayı dene
      setState(() {
        _isScanning = true;
        _statusMessage = 'Raspberry Pi aranıyor...';
      });
      
      bool found = await bluetoothService.findAndConnectToRaspberryPi();
      
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isConnected = bluetoothService.isConnected;
          _connectedDevice = bluetoothService.connectedDevice;
          
          if (_isConnected) {
            _statusMessage = '${_connectedDevice?.name ?? "Cihaz"} bağlandı!';
          } else {
            _statusMessage = found ? 'Bağlantı başarısız' : 'Raspberry Pi bulunamadı';
          }
          
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _scanForDevices() async {
    final bluetoothService = Provider.of<RaspBluetoothService>(
      context,
      listen: false,
    );

    setState(() {
      _isScanning = true;
      _statusMessage = 'Cihazlar aranıyor...';
    });

    try {
      bool found = await bluetoothService.findAndConnectToRaspberryPi();
      
      if (mounted) {
        setState(() {
          _isScanning = false;
          _isConnected = bluetoothService.isConnected;
          _connectedDevice = bluetoothService.connectedDevice;
          
          if (_isConnected) {
            _statusMessage = '${_connectedDevice?.name ?? "Cihaz"} bağlandı!';
          } else {
            _statusMessage = found ? 'Bağlantı başarısız' : 'Raspberry Pi bulunamadı';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _statusMessage = 'Hata: $e';
        });
      }
    }
  }

  Future<void> _sendWifiCredentials() async {
    // SSID kontrolü
    String ssid = _useCurrentWifi ? _currentWifiSSID ?? '' : _ssidController.text.trim();
    String password = _passwordController.text.trim();
    
    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi SSID boş olamaz')),
      );
      return;
    }

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WiFi şifresi boş olamaz')),
      );
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bluetooth cihazına bağlı değilsiniz')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'WiFi bilgileri gönderiliyor...';
    });

    final bluetoothService = Provider.of<RaspBluetoothService>(
      context,
      listen: false,
    );

    try {
      final success = await bluetoothService.sendWifiCredentials(ssid, password);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = success
              ? 'WiFi bilgileri başarıyla gönderildi!'
              : 'WiFi bilgileri gönderilemedi.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'WiFi bilgileri başarıyla gönderildi'
                  : 'WiFi bilgileri gönderilemedi',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = 'Hata: $e';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF383B39),
      child: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFB2BEB5)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık
                  const Text(
                    'Raspberry Pi Bluetooth Bağlantısı',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB2BEB5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bluetooth Durumu Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2C2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB2BEB5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                              color: _isConnected ? const Color(0xFFa64242) : const Color(0xFFB2BEB5),
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Bluetooth Durumu',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: _isConnected ? const Color(0xFFa64242) : const Color(0xFFB2BEB5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected
                              ? 'Bağlı Cihaz: ${_connectedDevice?.name ?? "Bilinmeyen Cihaz"}'
                              : 'Bağlı Cihaz Yok',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFFB2BEB5),
                          ),
                        ),
                        if (_statusMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 14,
                              color: _isConnected ? Colors.green : const Color(0xFFB2BEB5),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? null : _scanForDevices,
                            icon: const Icon(Icons.search),
                            label: Text(_isScanning ? 'Aranıyor...' : 'Cihazları Ara'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFa64242),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // WiFi Yapılandırma Kartı
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2C2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFB2BEB5), width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.wifi,
                              color: Color(0xFFB2BEB5),
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'WiFi Yapılandırması',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB2BEB5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Mevcut WiFi'yı kullan checkbox
                        Row(
                          children: [
                            Theme(
                              data: ThemeData(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor: MaterialStateProperty.resolveWith((states) {
                                    if (states.contains(MaterialState.selected)) {
                                      return const Color(0xFFa64242);
                                    }
                                    return const Color(0xFFB2BEB5);
                                  }),
                                ),
                              ),
                              child: Checkbox(
                                value: _useCurrentWifi,
                                onChanged: (value) {
                                  setState(() {
                                    _useCurrentWifi = value ?? true;
                                  });
                                },
                              ),
                            ),
                            const Text(
                              'Mevcut WiFi ağını kullan',
                              style: TextStyle(
                                color: Color(0xFFB2BEB5),
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // WiFi SSID Alanı
                        if (_useCurrentWifi) ...[
                          // Mevcut WiFi bilgisi
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF383B39),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF70786E)),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.wifi,
                                  color: Color(0xFFB2BEB5),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mevcut WiFi Ağı',
                                        style: TextStyle(
                                          color: Color(0xFF70786E),
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _currentWifiSSID ?? 'Bağlı değil',
                                        style: const TextStyle(
                                          color: Color(0xFFB2BEB5),
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Custom SSID girişi
                          TextField(
                            controller: _ssidController,
                            decoration: const InputDecoration(
                              labelText: 'WiFi SSID (Ağ Adı)',
                              labelStyle: TextStyle(color: Color(0xFF70786E)),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFF70786E)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Color(0xFFa64242)),
                              ),
                              prefixIcon: Icon(Icons.wifi, color: Color(0xFF70786E)),
                              filled: true,
                              fillColor: Color(0xFF383B39),
                            ),
                            style: const TextStyle(color: Color(0xFFB2BEB5)),
                          ),
                        ],
                        
                        const SizedBox(height: 16),
                        
                        // WiFi Password Field
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'WiFi Şifresi',
                            labelStyle: TextStyle(color: Color(0xFF70786E)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFF70786E)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFa64242)),
                            ),
                            prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF70786E)),
                            filled: true,
                            fillColor: Color(0xFF383B39),
                          ),
                          obscureText: true,
                          style: const TextStyle(color: Color(0xFFB2BEB5)),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Gönder Butonu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isConnected ? _sendWifiCredentials : null,
                            icon: const Icon(Icons.send),
                            label: const Text(
                              'WiFi Bilgilerini Gönder',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFa64242),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        
                        if (!_isConnected) ...[
                          const SizedBox(height: 8),
                          const Center(
                            child: Text(
                              'WiFi bilgilerini göndermek için önce bir Bluetooth cihazına bağlanın',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF70786E),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
