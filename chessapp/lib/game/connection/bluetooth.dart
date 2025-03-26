import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chessapp/components/constants.dart';
import 'package:logger/logger.dart';

var logger = Logger();

mixin BluetoothHandler {
  bool isBluetoothConnected = false;
  late BluetoothDevice _connectedDevice;

  Future<void> requestBluetoothPermissions() async {
    logger.i("Requesting permissions...");

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted =
        statuses.values.every((status) => status == PermissionStatus.granted);

    statuses.forEach((permission, status) {
      logger.i('$permission: $status');
    });

    if (!allGranted) {
      logger.e("Error: Not all required permissions were granted.");
      return;
    }

    print("All required permissions granted.");
    print("Starting Bluetooth scan...");
  }

  Future startScan() async {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
  }

  Future<void> scanAndConnectBluetooth() async {
    if (await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothConnect.isDenied ||
        await Permission.locationWhenInUse.isDenied) {
      print("Required permissions are not granted!");
      return;
    }
    print("Permissions granted.");

    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      print("Bluetooth is off. Please enable Bluetooth.");
      return;
    }
    await startScan();

    List<ScanResult> scanResults = [];
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      try {
        scanResults = results;
      } catch (e) {
        print("Error in scan results listener: $e");
      }
    });
    print("Listening for scan results...");

    await Future.delayed(Duration(seconds: 4));

    print("Scanning stopped.");
    await FlutterBluePlus.stopScan();
    print("Scan results received.");
    subscription.cancel();
    print("Subscription cancelled.");

    if (scanResults.isEmpty) {
      print("No Bluetooth devices found.");
      return;
    }

    print("Scan results:");
    for (var result in scanResults) {
      print(
          "Device: ${result.device.platformName}, ID: ${result.device.remoteId}");
    }

    late BluetoothDevice arduinoDevice;
    for (var result in scanResults) {
      if (result.device.platformName == ARDUINO_NAME) {
        arduinoDevice = result.device;
        print(
            "Found Arduino: ${arduinoDevice.platformName} (${arduinoDevice.remoteId})");
        break;
      }
    }

    try {
      await arduinoDevice.connect();
      print("Connected to ${arduinoDevice.platformName}");

      List<BluetoothService> services = await arduinoDevice.discoverServices();
      for (var service in services) {
        print("[Service] ${service.uuid}");
        for (var characteristic in service.characteristics) {
          print(
              "  [Characteristic] ${characteristic.uuid} - ${characteristic.properties}");
        }
      }

      _connectedDevice = arduinoDevice;
      isBluetoothConnected = true;
    } catch (e) {
      print("Error connecting to Arduino: $e");
    }
  }

  Future<void> updateCharacteristics(
      Map<String, dynamic> game, String ssid, String password) async {
    try {
      List<BluetoothService> services =
          await _connectedDevice.discoverServices();

      for (var service in services) {
        for (var characteristic in service.characteristics) {
          if (characteristic.uuid.toString() == SSID_CHAR_UUID) {
            await characteristic.write(utf8.encode(ssid));
            print("SSID updated.");
          } else if (characteristic.uuid.toString() == PASSWORD_CHAR_UUID) {
            await characteristic.write(utf8.encode(password));
            print("Password updated.");
          } else if (characteristic.uuid.toString() == GAMEID_CHAR_UUID) {
            await characteristic.write(utf8.encode(game['gameID']));
            print("Game ID updated.");
          } else if (characteristic.uuid.toString() == PLAYERID_CHAR_UUID) {
            await characteristic.write(utf8.encode(PLAYERID));
            print("User ID updated.");
          } else if (characteristic.uuid.toString() == RESET_CHAR_UUID) {
            await characteristic.write(utf8.encode("0"));
            print("Reset signal sent.");
          } else if (characteristic.uuid.toString() == USE_TYPE_CHAR_UUID) {
            await characteristic.write(utf8.encode("play"));
            print("Use type updated.");
          }
        }
      }
    } catch (e) {
      print("Error updating characteristics: $e");
    }
  }

  void checkBluetoothConnection() async {
    try {
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          print("Bluetooth is on.");
          isBluetoothConnected = true;
        } else {
          print("Bluetooth is off.");
          isBluetoothConnected = false;
          _attemptReconnect();
        }
      });
    } catch (e) {
      print("Error checking Bluetooth connection: $e");
    }
  }

  void _attemptReconnect() async {
    print("Attempting to reconnect to Bluetooth...");
    await scanAndConnectBluetooth();
  }

  void transmitGameToBoard(
      Map<String, dynamic> game, String ssid, String password) async {
    try {
      await updateCharacteristics(game, ssid, password);
      print("Game data transmitted: ${game['gameID']}");
      print("Wi-Fi SSID: $ssid, Password: $password");
    } catch (e) {
      print("Error transmitting game to board: $e");
    }
  }
}
