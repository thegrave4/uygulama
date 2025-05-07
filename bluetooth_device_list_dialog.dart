import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';

// Not: Bu dosya yeni tasarımda kullanılmamaktadır, ancak gelecekte manuel cihaz seçimi gerekirse kullanılabilir.
class BluetoothDeviceListDialog extends StatelessWidget {
  final List<BluetoothDevice> devices;

  const BluetoothDeviceListDialog({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: Color(0xFF383B39),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bluetooth Cihazları',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB2BEB5),
              ),
            ),
            const SizedBox(height: 16),
            devices.isEmpty
                ? const Center(
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      CircularProgressIndicator(color: Color(0xFFB2BEB5)),
                      SizedBox(height: 16),
                      Text(
                        'Cihazlar aranıyor...',
                        style: TextStyle(color: Color(0xFFB2BEB5)),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                )
                : Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      return ListTile(
                        title: Text(
                          device.name,
                          style: const TextStyle(color: Color(0xFFB2BEB5)),
                        ),
                        subtitle: Text(
                          device.id,
                          style: const TextStyle(
                            color: Color(0xFF70786E),
                            fontSize: 12,
                          ),
                        ),
                        leading: const Icon(
                          Icons.bluetooth,
                          color: Color(0xFFB2BEB5),
                        ),
                        onTap: () {
                          Navigator.of(context).pop(device);
                        },
                      );
                    },
                  ),
                ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'İptal',
                    style: TextStyle(color: Color(0xFFB2BEB5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
