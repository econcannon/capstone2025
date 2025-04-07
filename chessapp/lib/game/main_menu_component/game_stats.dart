// Flutter package imports
import 'package:chessapp/game/get_data/stats.dart';
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

class GameStatsScreen extends StatefulWidget {
  const GameStatsScreen({super.key});

  @override
  _GameStatsScreenState createState() => _GameStatsScreenState();
}

class _GameStatsScreenState extends State<GameStatsScreen> with StatsHandler {
  List<Map<String, dynamic>> games = [];
  //Map<String, dynamic> games = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAndSetGames();
  }

Future<void> fetchAndSetGames() async {
  final data = await fetchGames();
  if (data != null && data["games"] != null) {
    setState(() {
      games = List<Map<String, dynamic>>.from(data["games"]);
      isLoading = false;
    });
  } else {
    setState(() => isLoading = false);
  }
  printGamesList();
}

  void printGamesList() {
    if (games.isEmpty) {
      print("No games found.");
      return;
    }

    // print("Games List:");
    // for (var i = 0; i < games.length; i++) {
    //   final game = games[i];
    //   print("Game ${i + 1}:");
    //   print("  Game ID: ${game["id"] ?? game["gameID"]}");
    //   print("  White Player: ${game["player_white"] ?? "Unknown"}");
    //   print("  Black Player: ${game["player_black"] ?? "Unknown"}");
    //   print("  Winner: ${game["winner"] ?? "Ongoing"}");
    //   print("  Ended At: ${game["ended_at"] ?? "In progress"}");
    //   print("  Moves: ${game["moves"] ?? "No moves available"}");
    //   print("-----------------------------");
    // }
    print("Games List:");
    for (var i = 0; i < games.length; i++) {
      final game = games[i];
      print("Game ${i + 1}:");
      print(game); // Print the entire game object
      print("-----------------------------");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (games.isEmpty) return const Center(child: Text("No games found."));

    return Scaffold(
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: games.length,
        itemBuilder: (context, index) {
          final game = games[index];
          return buildGameCard(context, game);
        },
      ),
    );
  }

  Widget buildGameCard(BuildContext context, Map<String, dynamic> game) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GameDetailsScreen(game: game),
          ),
        );
      },
      child: Card(
        color: HexColor("#EDEDED"),
        elevation: 3,
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Game ID: ${game["id"] ?? game["gameID"]}",
                  style: GoogleFonts.dmSans(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("White: ${game["player_white"] ?? "?"}",
                  style: GoogleFonts.dmSans(fontSize: 14)),
              Text("Black: ${game["player_black"] ?? "?"}",
                  style: GoogleFonts.dmSans(fontSize: 14)),
              Text("Winner: ${game["winner"] ?? "Ongoing"}",
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text("Ended At: ${game["ended_at"] ?? "In progress"}",
                  style: GoogleFonts.dmSans(
                      fontSize: 14, color: HexColor("#44564A"))),
            ],
          ),
        ),
      ),
    );
  }
}

class GameDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> game;

  const GameDetailsScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final moves = List<String>.from(game["moves"]);
    return Scaffold(
      appBar: AppBar(
        title: Text("Game ID: ${game["id"]}",
            style: GoogleFonts.dmSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black)),
        backgroundColor: HexColor("#D0B38B"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("White: ${game["player_white"]}",
                style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Black: ${game["player_black"]}",
                style: GoogleFonts.dmSans(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Winner: ${game["winner"] ?? "Ongoing"}",
                style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green)),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 10),
            Text("Moves:",
                style: GoogleFonts.dmSans(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: moves.length,
                itemBuilder: (context, index) {
                  final move = moves[index];
                  final color = index % 2 == 0 ? "white" : "black";
                  return ListTile(
                    leading: Text("#${index + 1}",
                        style: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    title: Text(
                      "Move: $move",
                      style: GoogleFonts.dmSans(fontSize: 16),
                    ),
                    trailing: Text(
                      color == "white" ? "⚪ White" : "⚫ Black",
                      style: GoogleFonts.dmSans(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
