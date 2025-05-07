import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as flutter_blue_plus;
import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class BluetoothDevice {
  final String name;
  final String id;
  final flutter_blue_plus.ScanResult scanResult;

  BluetoothDevice({
    required this.name,
    required this.id,
    required this.scanResult,
  });
}

class RaspBluetoothService {
  final List<BluetoothDevice> _devicesList = [];
  bool _isConnected = false;
  flutter_blue_plus.BluetoothConnectionState _connectionState =
      flutter_blue_plus.BluetoothConnectionState.disconnected;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _scanSubscription;
  BluetoothDevice? _connectedDevice;
  flutter_blue_plus.BluetoothCharacteristic? _writeCharacteristic;
  flutter_blue_plus.BluetoothCharacteristic? _readCharacteristic;
  StreamSubscription? _readSubscription;

  // Raspberry Pi cihaz adı için filtre
  // Bunu özel cihazınızın adına uyarlayın veya bir liste olarak tanımlayın
  final List<String> _raspberryPiDeviceNameFilters = [
    'Raspberry',
    'RPi',
    'RaspTemp',
    'Pi',
    'PiTemp',
    'raspberrypi',
  ];

  // RFCOMM Service UUID - Standart SPP UUID for RFCOMM
  final String RFCOMM_UUID = "00001101-0000-1000-8000-00805F9B34FB";

  // Getters
  List<BluetoothDevice> get devicesList => _devicesList;
  bool get isConnected => _isConnected;
  BluetoothDevice? get connectedDevice => _connectedDevice;

  // Initialize Bluetooth
  Future<bool> initBluetooth(BuildContext context) async {
    try {
      // Check if Bluetooth is available and enabled
      if (await flutter_blue_plus.FlutterBluePlus.isSupported == false) {
        debugPrint('Bluetooth not supported on this device');
        return false;
      }

      // Request permissions first
      bool permissionsGranted =
          await PermissionService.requestBluetoothPermissions(context);
      if (!permissionsGranted) {
        debugPrint('Bluetooth permissions not granted');
        return false;
      }

      // Check if Bluetooth is on
      var state = await flutter_blue_plus.FlutterBluePlus.adapterState.first;
      if (state != flutter_blue_plus.BluetoothAdapterState.on) {
        // Request user to enable Bluetooth
        try {
          await flutter_blue_plus.FlutterBluePlus.turnOn();
        } catch (e) {
          debugPrint('Error turning on Bluetooth: $e');

          // Show dialog asking user to enable Bluetooth manually
          if (context.mounted) {
            showDialog(
              context: context,
              builder:
                  (BuildContext context) => AlertDialog(
                    title: const Text('Bluetooth Kapalı'),
                    content: const Text(
                      'Bluetooth kapalı. Lütfen cihazınızın Bluetooth\'unu açın ve tekrar deneyin.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Tamam'),
                      ),
                    ],
                  ),
            );
          }
          return false;
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error initializing Bluetooth: $e');
      return false;
    }
  }

  // Start scanning for devices
  Future<void> startScan() async {
    _devicesList.clear();

    try {
      // Stop any previous scans
      await flutter_blue_plus.FlutterBluePlus.stopScan();

      // Listen for scan results
      _scanSubscription?.cancel();
      _scanSubscription = flutter_blue_plus.FlutterBluePlus.scanResults.listen((
        results,
      ) {
        for (flutter_blue_plus.ScanResult result in results) {
          // Only add devices with names (likely to be Raspberry Pi)
          if (result.device.platformName.isNotEmpty) {
            // Check if device is already in the list
            bool exists = _devicesList.any(
              (device) => device.id == result.device.remoteId.str,
            );

            if (!exists) {
              _devicesList.add(
                BluetoothDevice(
                  name: result.device.platformName,
                  id: result.device.remoteId.str,
                  scanResult: result,
                ),
              );
              debugPrint('Found device: ${result.device.platformName}');
            }
          }
        }
      });

      // Start scanning
      await flutter_blue_plus.FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 10),
        withServices: [
          flutter_blue_plus.Guid(RFCOMM_UUID),
        ], // Look for devices with RFCOMM service
      );
    } catch (e) {
      debugPrint('Error scanning for devices: $e');
    }
  }

  // Find and connect to any Raspberry Pi
  Future<bool> findAndConnectToRaspberryPi() async {
    try {
      await startScan();

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 5));

      // Find any device that matches Raspberry Pi naming filters
      BluetoothDevice? raspberryPi;
      for (var device in _devicesList) {
        for (var nameFilter in _raspberryPiDeviceNameFilters) {
          if (device.name.toLowerCase().contains(nameFilter.toLowerCase())) {
            raspberryPi = device;
            break;
          }
        }
        if (raspberryPi != null) break;
      }

      // If we found a Raspberry Pi, connect to it
      if (raspberryPi != null) {
        debugPrint('Found Raspberry Pi: ${raspberryPi.name}');
        return await connectToDevice(raspberryPi);
      }

      debugPrint('No Raspberry Pi devices found');
      return false;
    } catch (e) {
      debugPrint('Error finding Raspberry Pi: $e');
      return false;
    }
  }

  // Connect to a device
  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Disconnect any existing connection
      await disconnect();

      debugPrint('Connecting to device: ${device.name}');

      // Connect to the device
      await device.scanResult.device.connect();

      // Listen for connection state changes
      _connectionSubscription?.cancel();
      _connectionSubscription = device.scanResult.device.connectionState.listen(
        (state) {
          _connectionState = state;
          _isConnected =
              state == flutter_blue_plus.BluetoothConnectionState.connected;
          debugPrint('Connection state changed: $_isConnected');
        },
      );

      // Wait for connection
      await Future.delayed(const Duration(seconds: 2));

      if (_isConnected) {
        _connectedDevice = device;

        // Discover services
        List<flutter_blue_plus.BluetoothService> services =
            await device.scanResult.device.discoverServices();
        debugPrint('Discovered ${services.length} services');

        // Find the RFCOMM service for Raspberry Pi
        bool foundRfcommService = false;
        for (flutter_blue_plus.BluetoothService service in services) {
          debugPrint('Service UUID: ${service.uuid.toString()}');

          // Look specifically for the RFCOMM service
          if (service.uuid.toString().toUpperCase() ==
              RFCOMM_UUID.toUpperCase()) {
            debugPrint('Found RFCOMM service');
            foundRfcommService = true;

            for (flutter_blue_plus.BluetoothCharacteristic characteristic
                in service.characteristics) {
              // Look for writable and readable characteristics
              if (characteristic.properties.write ||
                  characteristic.properties.writeWithoutResponse) {
                debugPrint(
                  'Found writable characteristic: ${characteristic.uuid.toString()}',
                );
                _writeCharacteristic = characteristic;
              }

              if (characteristic.properties.read ||
                  characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                debugPrint(
                  'Found readable characteristic: ${characteristic.uuid.toString()}',
                );
                _readCharacteristic = characteristic;

                // Subscribe to notifications if available
                if (characteristic.properties.notify) {
                  await characteristic.setNotifyValue(true);
                  _readSubscription = characteristic.onValueReceived.listen((
                    value,
                  ) {
                    String response = utf8.decode(value);
                    debugPrint('Received from Raspberry Pi: $response');
                  });
                }
              }
            }
          }
        }

        // If we didn't find the specific RFCOMM service, fall back to any service with writable characteristics
        if (!foundRfcommService) {
          debugPrint(
            'RFCOMM service not found, falling back to any writable service',
          );
          for (flutter_blue_plus.BluetoothService service in services) {
            for (flutter_blue_plus.BluetoothCharacteristic characteristic
                in service.characteristics) {
              // Look for a writable characteristic
              if (characteristic.properties.write ||
                  characteristic.properties.writeWithoutResponse) {
                debugPrint(
                  'Found writable characteristic: ${characteristic.uuid.toString()}',
                );
                _writeCharacteristic = characteristic;
              }

              // Look for a readable characteristic
              if (characteristic.properties.read ||
                  characteristic.properties.notify ||
                  characteristic.properties.indicate) {
                debugPrint(
                  'Found readable characteristic: ${characteristic.uuid.toString()}',
                );
                _readCharacteristic = characteristic;

                // Subscribe to notifications if available
                if (characteristic.properties.notify) {
                  await characteristic.setNotifyValue(true);
                  _readSubscription = characteristic.onValueReceived.listen((
                    value,
                  ) {
                    String response = utf8.decode(value);
                    debugPrint('Received from Raspberry Pi: $response');
                  });
                }
              }
            }
            if (_writeCharacteristic != null) break;
          }
        }

        return _writeCharacteristic != null;
      }

      return false;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      _isConnected = false;
      return false;
    }
  }

  // Disconnect from device
  Future<void> disconnect() async {
    try {
      _readSubscription?.cancel();

      if (_connectedDevice != null) {
        if (_readCharacteristic != null &&
            _readCharacteristic!.properties.notify) {
          await _readCharacteristic!.setNotifyValue(false);
        }
        await _connectedDevice!.scanResult.device.disconnect();
      }

      _connectionSubscription?.cancel();
      _isConnected = false;
      _connectedDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
    } catch (e) {
      debugPrint('Error disconnecting: $e');
    }
  }

  // Send WiFi configuration to Raspberry Pi
  Future<bool> sendWifiConfig(String ssid, String password) async {
    if (_writeCharacteristic == null || !_isConnected) {
      debugPrint(
        'Cannot send WiFi config: not connected or no writable characteristic',
      );
      return false;
    }

    try {
      // Create the command format expected by Raspberry Pi
      // Format must match that expected in raspberry39.py: "WIFI:ssid:password"
      String commandData = "WIFI:$ssid:$password";

      debugPrint('Sending WiFi config: $commandData');

      // Send data
      await _writeCharacteristic!.write(
        utf8.encode(commandData),
        withoutResponse: false,
      );

      // If we have a readable characteristic, try to read the response
      String response = "";
      if (_readCharacteristic != null && _readCharacteristic!.properties.read) {
        // Try to read the response (this might not work depending on the device implementation)
        try {
          List<int> data = await _readCharacteristic!.read();
          response = utf8.decode(data);
          debugPrint('Response from Raspberry Pi: $response');
        } catch (e) {
          debugPrint('Error reading response: $e');
        }
      }

      // Wait for a bit to ensure the command is processed
      await Future.delayed(const Duration(seconds: 3));

      // Return true if we got a success response, or if we didn't get any response at all
      return response.isEmpty || response.contains("başarılı");
    } catch (e) {
      debugPrint('Error sending WiFi config: $e');
      return false;
    }
  }

  // Send WiFi credentials to Raspberry Pi
  Future<bool> sendWifiCredentials(String ssid, String password) async {
    if (!_isConnected || _writeCharacteristic == null) {
      debugPrint('Not connected or write characteristic not available');
      return false;
    }

    try {
      // Format the command as expected by the Python script
      String command = 'WIFI:$ssid:$password';
      List<int> bytes = utf8.encode(command);

      // Send the command
      await _writeCharacteristic!.write(bytes);

      // Wait for response (optional, depending on your needs)
      if (_readCharacteristic != null) {
        List<int> response = await _readCharacteristic!.read();
        String responseStr = utf8.decode(response);
        debugPrint('Response from Raspberry Pi: $responseStr');
        return responseStr.contains('başarılı') || responseStr.contains('success');
      }

      return true;
    } catch (e) {
      debugPrint('Error sending WiFi credentials: $e');
      return false;
    }
  }

  // Dispose resources
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _readSubscription?.cancel();
    disconnect();
  }
}
