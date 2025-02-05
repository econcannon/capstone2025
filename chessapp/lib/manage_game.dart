import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'chess.dart';

List<Map<String, dynamic>> games = [];
List<Map<String, dynamic>> get list_of_ongoing_games => games;

class ViewOngoingGame extends StatefulWidget {
  final String playerId;

  const ViewOngoingGame({super.key, required this.playerId});

  @override
  _ViewOngoingGameState createState() => _ViewOngoingGameState();
}

class _ViewOngoingGameState extends State<ViewOngoingGame> {
  @override
  void initState() {
    super.initState();
    _fetchGames();
  }

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
      }
    } catch (e) {
      print("Error deleting game: $e");
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
                          child: ElevatedButton(
                            onPressed: () => _deleteGame(game['gameID']),
                            child: const Text('Delete Game'),
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
