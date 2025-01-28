import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main.dart';
import 'chess.dart';

class ViewOngoingGame extends StatelessWidget {
  final String playerId;

  ViewOngoingGame({super.key, required this.playerId});

  Future<List<Map<String, dynamic>>> fetchOngoingGames() async {
    try {
      final endpoint = "$BASE_URL/player/games?playerID=$playerId";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['games'] != null) {
          return List<Map<String, dynamic>>.from(data['games']);
        }
      }

      print("No ongoing games found.");
      return [];
    } catch (e) {
      print("Error fetching games: $e");
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ongoing Games'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchOngoingGames(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No ongoing games found.'));
          }

          final games = snapshot.data!;
          return ListView.builder(
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return ListTile(
                title: Text("Game ID: ${game['gameID']}"),
                subtitle: Text(
                  "Players: ${game['players']}\nTurn: ${game['turn']}",
                ),
                isThreeLine: true,
              );
            },
          );
        },
      ),
    );
  }
}

class JoinExistingGame extends StatelessWidget {
  const JoinExistingGame({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController gameIdController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
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
              child: const Text('Join Existing Game'),
            ),
          ],
        ),
      ),
    );
  }
}
