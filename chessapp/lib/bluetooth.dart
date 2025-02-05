import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wifi_iot/wifi_iot.dart';
import 'constants.dart';
import 'manage_game.dart';

Future<void> sendGameToBoard(BluetoothDevice device, bool authenticated) async {
  if (!authenticated) {
    print("Please log in to send game to board.");
    return;
  }

  if (device.state != BluetoothDeviceState.connected) {
    print("No board connected. Please connect to a board first.");
    return;
  }

  var wifiInfo = await getConnectedWifiInfo();
  String? ssid = wifiInfo['ssid'];
  String? wifiPassword = wifiInfo['password'];

  if (ssid == null || wifiPassword == null) {
    print("Must be connected to WiFi.");
    return;
  }

  if (list_of_ongoing_games.isNotEmpty) {
    print("\n--- Ongoing list_of_ongoing_games ---");
    for (int i = 0; i < list_of_ongoing_games.length; i++) {
      print(
          "${i + 1}. Game ID: ${list_of_ongoing_games[i]['gameID']}, Opponent: ${list_of_ongoing_games[i]['players']}, Turn: ${list_of_ongoing_games[i]['turn']}");
    }

    int gameChoice = 5;

    if (gameChoice > 0 && gameChoice <= list_of_ongoing_games.length) {
      Map<String, dynamic> selectedGame = list_of_ongoing_games[gameChoice - 1];
      await transmitGameToBoard(device, selectedGame);
    } else {
      print("Invalid selection.");
    }
  }
}

Future<Map<String, String?>> getConnectedWifiInfo() async {
  try {
    String? ssid = await WiFiForIoTPlugin.getSSID();
    String? password = await WiFiForIoTPlugin.getWiFiPassword();

    return {'ssid': ssid, 'password': password};
  } catch (e) {
    print("Error retrieving WiFi info: $e");
    return {'ssid': null, 'password': null};
  }
}

Future<void> transmitGameToBoard(
    BluetoothDevice device, Map<String, dynamic> game) async {
  try {
    await updateCharacteristics(device, game);
    print("Game ${game['gameID']} sent to board.");
  } catch (e) {
    print("Error sending game to board: $e");
  }
}

Future<void> updateCharacteristics(
    BluetoothDevice device, Map<String, dynamic> game) async {
  List<BluetoothService> services = await device.discoverServices();

  for (var service in services) {
    for (var char in service.characteristics) {
      if (char.uuid.toString() == SSID_CHAR_UUID) {
        await char.write(utf8.encode(game["ssid"]!));
        print("SSID updated.");
      } else if (char.uuid.toString() == PASSWORD_CHAR_UUID) {
        await char.write(utf8.encode(game["password"]!));
        print("Password updated.");
      } else if (char.uuid.toString() == GAMEID_CHAR_UUID) {
        await char.write(utf8.encode(game["gameID"]!));
        print("Game ID updated.");
      } else if (char.uuid.toString() == PLAYERID_CHAR_UUID) {
        await char.write(utf8.encode(game["playerID"]!));
        print("User ID updated.");
      }
    }
  }
}
