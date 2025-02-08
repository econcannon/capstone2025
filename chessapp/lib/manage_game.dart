import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'chess.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class EnterWifiInfoPage extends StatefulWidget {
  final Function(String ssid, String password) onWifiInfoSubmitted;

  const EnterWifiInfoPage({Key? key, required this.onWifiInfoSubmitted})
      : super(key: key);

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

class ViewOngoingGame extends StatefulWidget {
  final String playerId;

  const ViewOngoingGame({super.key, required this.playerId});

  @override
  _ViewOngoingGameState createState() => _ViewOngoingGameState();
}

class _ViewOngoingGameState extends State<ViewOngoingGame> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  bool isBluetoothConnected = false;
  BluetoothDevice? _connectedDevice;

  String SSID_CHAR_UUID = "8266532f-1fe1-4af9-97e1-3b7c04ef8201";
  String PASSWORD_CHAR_UUID = "91abf729-1b45-4147-b8f7-b93620e8bce1";
  String GAMEID_CHAR_UUID = "5f91bb09-093c-42d7-b615-a2b110369a2e";
  String PLAYERID_CHAR_UUID = "bcf9cb8c-78f4-4b22-8f2c-ad5df34a34cd";
  String RESET_CHAR_UUID = "cfb3a8c4-85c7-4e9f-9f0b-b1c6e22b15e2";
  String ARDUINO_NAME = "GIGA_R1_Bluetooth";

  @override
  void initState() {
    super.initState();
    _fetchGames();
    _checkBluetoothConnection();
  }

  List<Map<String, dynamic>> games = [];
  List<Map<String, dynamic>> get list_of_ongoing_games => games;

  Future<void> _fetchGames() async {
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

  Future<void> _deleteGame(String gameID) async {
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

  Future<void> _deleteAllGames() async {
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

  Future<void> requestBluetoothPermissions() async {
    if (await Permission.bluetoothScan.isDenied ||
        await Permission.bluetoothConnect.isDenied) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
    }
  }

  Future<void> _scanAndConnectBluetooth() async {
    print("Scanning for Bluetooth devices...");

    // Start scanning
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));

    // Listen to scan results
    List<ScanResult> scanResults = [];
    var subscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults = results;
    });

    // Wait for the scan to complete
    await Future.delayed(Duration(seconds: 4));
    await FlutterBluePlus.stopScan();
    subscription.cancel();

    if (scanResults.isEmpty) {
      print("No Bluetooth devices found.");
      return;
    }

    late BluetoothDevice arduinoDevice;
    for (var result in scanResults) {
      if (result.device.platformName == ARDUINO_NAME) {
        arduinoDevice = result.device;
        print(
            "Found Arduino: ${arduinoDevice.platformName} (${arduinoDevice.id})");
        break;
      }
    }

    if (arduinoDevice != null) {
      try {
        await arduinoDevice.connect();
        print("Connected to ${arduinoDevice.platformName}");

        List<BluetoothService> services =
            await arduinoDevice.discoverServices();
        for (var service in services) {
          print("[Service] ${service.uuid}");
          for (var characteristic in service.characteristics) {
            print(
                "  [Characteristic] ${characteristic.uuid} - ${characteristic.properties}");
          }
        }

        _connectedDevice = arduinoDevice;
      } catch (e) {
        print("Error connecting to Arduino: $e");
      }
    } else {
      print("Arduino not found. Please ensure it is powered on and in range.");
    }
  }

  Future<void> _updateCharacteristics(
      Map<String, dynamic> game, String ssid, String password) async {
    if (_connectedDevice == null) {
      print("No device connected.");
      return;
    }

    try {
      List<BluetoothService> services =
          await _connectedDevice!.discoverServices();

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

  Future<void> _checkBluetoothConnection() async {
    try {
      FlutterBluePlus.adapterState.listen((state) {
        if (state == BluetoothAdapterState.on) {
          setState(() {
            isBluetoothConnected = true;
          });
        } else {
          setState(() {
            isBluetoothConnected = false;
          });
        }
      });
    } catch (e) {
      print("Error checking Bluetooth connection: $e");
    }
  }

  Future<void> _sendGameToBoard(Map<String, dynamic> game) async {
    if (!isBluetoothConnected) {
      print("No board connected. Please connect to a board first.");
      return;
    }

    if (_connectedDevice == null) {
      await _scanAndConnectBluetooth();
    }

    if (_connectedDevice != null) {
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
    } else {
      print("Failed to connect to the board.");
    }
  }

  Future<void> _transmitGameToBoard(
      Map<String, dynamic> game, String ssid, String password) async {
    try {
      await _updateCharacteristics(game, ssid, password);
      print("Game data transmitted: ${game['gameID']}");
      print("Wi-Fi SSID: $ssid, Password: $password");
    } catch (e) {
      print("Error transmitting game to board: $e");
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
                                  // Add functionality for joining the game
                                  print("Join game: ${game['gameID']}");
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
