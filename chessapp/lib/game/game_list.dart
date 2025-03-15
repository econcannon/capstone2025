import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'chess.dart';
import '../components/constants.dart';
import 'package:chessapp/game/join_game/bluetooth.dart';
import 'package:chessapp/game/join_game/wifi.dart';

class ViewOngoingGame extends StatefulWidget {
  final String playerId;

  const ViewOngoingGame({super.key, required this.playerId});

  @override
  _ViewOngoingGameState createState() => _ViewOngoingGameState();
}

class _ViewOngoingGameState extends State<ViewOngoingGame> with BluetoothHandler {

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    await requestBluetoothPermissions();
    checkBluetoothConnection();
    _fetchGames();
  }
  List<Map<String, dynamic>> games = [];

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

   void _sendGameToBoard(Map<String, dynamic> game) async {
    if (!isBluetoothConnected) {
      print("No board connected. Please connect to a board first.");
      return;
    }

    await scanAndConnectBluetooth();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EnterWifiInfoPage(
          onWifiInfoSubmitted: (ssid, password) {
            print("SSID: $ssid, Password: $password");
            transmitGameToBoard(game, ssid, password);
          },
        ),
      ),
    );
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

