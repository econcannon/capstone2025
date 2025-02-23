import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

class BlueToothController extends GetxController {
  @override
  void onInit() {
    super.onInit();
    requestBluetoothPermission();
  }

  Future<void> requestBluetoothPermission() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
    ].request();
    
    statuses.forEach((permission, status) {
      print('$permission: $status');
    });
  }

  Future scanDevices() async {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 5));
    FlutterBluePlus.stopScan();
  }

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
}

class BlueToothPage extends StatelessWidget {
  const BlueToothPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetBuilder<BlueToothController>(
      init: BlueToothController(),
      builder: (controller) {
        return SingleChildScrollView(
            child: Column(children: [
          Container(
            height: 180,
            width: double.infinity,
            color: Colors.blue,
            child: const Center(
              child: Text(
                'Bluetooth Devices',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: () => controller.scanDevices(),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                minimumSize: const Size(350, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(5))),
              ),
              child: const Text('Scan Devices', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<ScanResult>>(
              stream: controller.scanResults,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      final data = snapshot.data![index];
                      return Card(
                          elevation: 2,
                          child: ListTile(
                            title: Text(data.device.platformName),
                            subtitle: Text(data.device.remoteId.str),
                            trailing: Text(data.rssi.toString()),
                          ));
                    },
                  );
                } else {
                  return const Center(
                    child: Text("no devices found"),
                  );
                }
              })
        ]));
      },
    );
  }
}
