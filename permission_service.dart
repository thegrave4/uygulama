import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request Bluetooth permissions based on platform and Android version
  static Future<bool> requestBluetoothPermissions(BuildContext context) async {
    if (Platform.isIOS) {
      // iOS için sadece bluetooth izinlerini iste
      final status = await Permission.bluetooth.request();
      return status.isGranted;
    }

    // Android için gerekli izinleri topla
    List<Permission> permissions = [];

    // Android 12 ve üzeri için ayrı izinler
    if (Platform.isAndroid) {
      permissions.add(Permission.bluetooth);

      try {
        // Eğer bluetoothScan/bluetoothConnect tanımlı değilse hata verecek ve catch bloğuna düşecek
        permissions.add(Permission.bluetoothScan);
        permissions.add(Permission.bluetoothConnect);

        // Android < 12 için lokasyon izni gerekli
        permissions.add(Permission.locationWhenInUse);
      } catch (e) {
        debugPrint('Permission error: $e');
        // Daha eski Android versiyonları için sadece bluetooth ve lokasyon izni
        permissions.add(Permission.locationWhenInUse);
      }
    }

    // Tüm izinleri iste
    Map<Permission, PermissionStatus> statuses = {};

    try {
      statuses = await permissions.request();
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      // Sadece temel izinleri deneyelim
      final bluetoothStatus = await Permission.bluetooth.request();
      final locationStatus = await Permission.locationWhenInUse.request();

      return bluetoothStatus.isGranted && locationStatus.isGranted;
    }

    // İzinlerden herhangi biri reddedildi mi kontrol et
    bool allGranted = true;
    statuses.forEach((permission, status) {
      debugPrint('Permission $permission: $status');
      if (!status.isGranted) {
        allGranted = false;
      }
    });

    // İzinler reddedildiyse, izinlerin neden gerekli olduğunu açıklayan bir iletişim kutusu göster
    if (!allGranted && context.mounted) {
      showDialog(
        context: context,
        builder:
            (BuildContext context) => AlertDialog(
              title: const Text('İzinler Gerekli'),
              content: const Text(
                'Bluetooth cihazları taramak ve bağlanmak için gerekli izinlere ihtiyacımız var. '
                'Lütfen ayarlardan uygulamaya gereken izinleri verin.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    openAppSettings();
                  },
                  child: const Text('Ayarları Aç'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('İptal'),
                ),
              ],
            ),
      );
      return false;
    }

    return allGranted;
  }
}
