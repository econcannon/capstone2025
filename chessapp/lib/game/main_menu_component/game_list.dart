import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:logger/logger.dart';

import 'dart:convert';
import '../chess.dart';
import '../../components/constants.dart';
import 'package:chessapp/game/connection/bluetooth.dart';
import 'package:chessapp/game/connection/wifi.dart';
import 'package:chessapp/game/main_menu.dart';

var logger = Logger();

class ViewOngoingGame extends StatefulWidget {
  final String playerId;

  const ViewOngoingGame({super.key, required this.playerId});

  @override
  _ViewOngoingGameState createState() => _ViewOngoingGameState();
}

class _ViewOngoingGameState extends State<ViewOngoingGame>
    with BluetoothHandler {
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
        backgroundColor: HexColor("#44564A"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MainMenu(),
              ),
            );
          },
        ),
        title: Text(
          "Chess Link",
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            color: Colors.white, 
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
                  color: HexColor("#EDEDED"),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Game ID: ${game['gameID']}",
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: 0,
                              color: Colors.black,
                            )),
                        const SizedBox(height: 8.0),
                        Text("Players: ${game['players']}",
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: 0,
                              color: Colors.black,
                            )),
                        const SizedBox(height: 8.0),
                        Text("Turn: ${game['turn']}",
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              letterSpacing: 0,
                              color: Colors.black,
                            )),
                        const SizedBox(height: 16.0),
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton(
                                onPressed: () => _deleteGame(game['gameID']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HexColor("#44564A"),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HexColor("#44564A"),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Join'),
                              ),
                              ElevatedButton(
                                onPressed: () => _sendGameToBoard(game),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: HexColor("#44564A"),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
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
