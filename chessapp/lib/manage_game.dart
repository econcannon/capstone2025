import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'chess.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart'; 
import 'package:get/get.dart';

class ViewOngoingGame extends StatefulWidget {
  final String playerId;

  const ViewOngoingGame({super.key, required this.playerId});

  @override
  _ViewOngoingGameState createState() => _ViewOngoingGameState();
}

class _ViewOngoingGameState extends State<ViewOngoingGame> {
  bool isBluetoothConnected = false;
  late BluetoothDevice _connectedDevice;

  String SSID_CHAR_UUID = "8266532f-1fe1-4af9-97e1-3b7c04ef8201";
  String PASSWORD_CHAR_UUID = "91abf729-1b45-4147-b8f7-b93620e8bce1";
  String GAMEID_CHAR_UUID = "5f91bb09-093c-42d7-b615-a2b110369a2e";
  String PLAYERID_CHAR_UUID = "bcf9cb8c-78f4-4b22-8f2c-ad5df34a34cd";
  String RESET_CHAR_UUID = "cfb3a8c4-85c7-4e9f-9f0b-b1c6e22b15e2";
  String ARDUINO_NAME = "GIGA_R1_Bluetooth";

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    await _requestBluetoothPermissions();
    _checkBluetoothConnection();
    _fetchGames();
  }

  List<Map<String, dynamic>> games = [];

  Future<void> _requestBluetoothPermissions() async {
    print("Requesting permissions...");

    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    bool allGranted =
        statuses.values.every((status) => status == PermissionStatus.granted);

    statuses.forEach((permission, status) {
      print('$permission: $status');
    });

    if (!allGranted) {
      print("Error: Not all required permissions were granted.");
      return;
    }

    print("All required permissions granted.");
    print("Starting Bluetooth scan...");
  }

  Future startScan() async {
    FlutterBluePlus.startScan(timeout: Duration(seconds: 10));
  }

  Future<void> _scanAndConnectBluetooth() async {
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

      setState(() {
        _connectedDevice = arduinoDevice;
        isBluetoothConnected = true;
      });
    } catch (e) {
      print("Error connecting to Arduino: $e");
    }
  }

  Future<void> _updateCharacteristics(
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
            await characteristic.write(utf8.encode(widget.playerId));
            print("User ID updated.");
          }
        }
      }
    } catch (e) {
      print("Error updating characteristics: $e");
    }
  }

  void _checkBluetoothConnection() async {
    try {
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          setState(() {
            print("Bluetooth is on.");
            isBluetoothConnected = true;
          });
        } else {
          setState(() {
            print("Bluetooth is off.");
            isBluetoothConnected = false;
          });
          _attemptReconnect();
        }
      });
    } catch (e) {
      print("Error checking Bluetooth connection: $e");
    }
  }

  void _attemptReconnect() async {
    print("Attempting to reconnect to Bluetooth...");
    await _scanAndConnectBluetooth();
  }

  void _sendGameToBoard(Map<String, dynamic> game) async {
    if (!isBluetoothConnected) {
      print("No board connected. Please connect to a board first.");
      return;
    }

    await _scanAndConnectBluetooth();
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnterWifiInfoPage(
          onWifiInfoSubmitted: (ssid, password) {
            print("SSID: $ssid, Password: $password");
            _transmitGameToBoard(game, ssid, password);
          },
        ),
      ),
    );
  }

  void _transmitGameToBoard(
      Map<String, dynamic> game, String ssid, String password) async {
    try {
      await _updateCharacteristics(game, ssid, password);
      print("Game data transmitted: ${game['gameID']}");
      print("Wi-Fi SSID: $ssid, Password: $password");
    } catch (e) {
      print("Error transmitting game to board: $e");
    }
  }

  void _fetchGames() async {
    try {
      final endpoint = "$BASE_URL/player/games?playerID=${widget.playerId}";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['games'] != null) {
          setState(() {
            games = List<Map<String, dynamic>>.from(data['games']);
          });
        }
      } else {
        print("Failed to fetch games.");
      }
    } catch (e) {
      print("Error fetching games: $e");
    }
  }

  void _deleteGame(String gameID) async {
    try {
      final endpoint =
          "$BASE_URL/player/end-game?playerID=${widget.playerId}&gameID=$gameID";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        print("Game deleted successfully.");

        setState(() {
          games.removeWhere((game) => game['gameID'] == gameID);
        });
      } else {
        print("Failed to delete game.");
        print(response.statusCode);
        print(response.body);
      }
    } catch (e) {
      print("Error deleting game: $e");
    }
  }

  void _deleteAllGames() async {
    try {
      final endpoint =
          "$BASE_URL/player/end-all-games?playerID=${widget.playerId}";
      final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        print("All games deleted successfully.");
        setState(() {
          games.clear();
        });
      } else {
        print("Failed to delete all games.");
      }
    } catch (e) {
      print("Error deleting all games: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongoing Games'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteAllGames,
          ),
        ],
      ),
      body: games.isEmpty
          ? const Center(child: Text('No ongoing games found.'))
          : ListView.builder(
              itemCount: games.length,
              itemBuilder: (context, index) {
                final game = games[index];
                return Card(
                  margin: const EdgeInsets.all(8.0),
                  elevation: 4.0,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Game ID: ${game['gameID']}"),
                        const SizedBox(height: 8.0),
                        Text("Players: ${game['players']}"),
                        const SizedBox(height: 8.0),
                        Text("Turn: ${game['turn']}"),
                        const SizedBox(height: 16.0),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => _deleteGame(game['gameID']),
                                child: const Text('Delete'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  print("Join game: ${game['gameID']}");
                                  GAMEID = game['gameID'];
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            GamePage(gameId: GAMEID)),
                                  );
                                },
                                child: const Text('Join'),
                              ),
                              ElevatedButton(
                                onPressed: () => _sendGameToBoard(game),
                                child: const Text('Send to Board'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class EnterWifiInfoPage extends StatefulWidget {
  final Function(String ssid, String password) onWifiInfoSubmitted;

  const EnterWifiInfoPage({super.key, required this.onWifiInfoSubmitted});

  @override
  _EnterWifiInfoPageState createState() => _EnterWifiInfoPageState();
}

class _EnterWifiInfoPageState extends State<EnterWifiInfoPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Wi-Fi Information")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(labelText: "Wi-Fi SSID"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Wi-Fi Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String ssid = ssidController.text;
                String password = passwordController.text;

                if (ssid.isNotEmpty && password.isNotEmpty) {
                  widget.onWifiInfoSubmitted(ssid, password);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Please enter both SSID and password.")),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}

class JoinGameWithID extends StatelessWidget {
  const JoinGameWithID({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController gameIdController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game by ID'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: gameIdController,
              decoration: const InputDecoration(
                labelText: 'Game ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GAMEID = gameIdController.text;
                if (GAMEID.isEmpty) {
                  print("Error: Game ID is required.");
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => GamePage(gameId: GAMEID)),
                );
              },
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}
