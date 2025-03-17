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
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAndSetGames();
  }

  Future<void> fetchAndSetGames() async {
    await Future.delayed(const Duration(seconds: 1));
    //final fetchedGames = await fetchGames();

    // if (fetchedGames != null) {
    //   setState(() {
    //     games = fetchedGames;
    //     isLoading = false;
    //   });
    // } else {
    //   setState(() {
    //     isLoading = false;
    //   });
    //   debugPrint("Failed to fetch game data.");
    // }
    
    setState(() {
      games = dummyGames;
      isLoading = false;
    });

  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: games.length,
            itemBuilder: (context, index) {
              final game = games[index];
              return buildGameCard(context, game);
            },
          );
  }

  Widget buildGameCard(BuildContext context, dynamic game) {
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
              Text("Game ID: ${game["id"]}",
                  style: GoogleFonts.dmSans(
                      fontSize: 16, fontWeight: FontWeight.bold)),
              Text("White: ${game["player_white"]}",
                  style: GoogleFonts.dmSans(fontSize: 14)),
              Text("Black: ${game["player_black"]}",
                  style: GoogleFonts.dmSans(fontSize: 14)),
              Text("Winner: ${game["winner"]}",
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.bold)),
              Text("Ended At: ${game["ended_at"]}",
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
  final dynamic game;

  const GameDetailsScreen({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
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
            Text("Winner: ${game["winner"]}",
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
                itemCount: game["moves"].length,
                itemBuilder: (context, index) {
                  final move = game["moves"][index];
                  return ListTile(
                    leading: Text("#${index + 1}",
                        style: GoogleFonts.dmSans(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    title: Text(
                      "From: ${move["from"]} → To: ${move["to"]}",
                      style: GoogleFonts.dmSans(fontSize: 16),
                    ),
                    trailing: Text(
                      move["color"] == "white" ? "⚪ White" : "⚫ Black",
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

// Dummy Data for Testing
List<Map<String, dynamic>> dummyGames = [
  {
    "id": 1,
    "player_white": "Alice",
    "player_black": "Bob",
    "winner": "white",
    "status": "completed",
    "ended_at": "2025-03-15T12:30:00Z",
    "moves": [
      {"from": "e2", "to": "e4", "color": "white"},
      {"from": "e7", "to": "e5", "color": "black"},
      {"from": "g1", "to": "f3", "color": "white"},
      {"from": "b8", "to": "c6", "color": "black"}
    ]
  },
  {
    "id": 2,
    "player_white": "Charlie",
    "player_black": "David",
    "winner": "black",
    "status": "completed",
    "ended_at": "2025-03-16T14:45:00Z",
    "moves": [
      {"from": "d2", "to": "d4", "color": "white"},
      {"from": "d7", "to": "d5", "color": "black"},
      {"from": "c1", "to": "f4", "color": "white"},
      {"from": "g8", "to": "f6", "color": "black"}
    ]
  },
  {
    "id": 3,
    "player_white": "Eve",
    "player_black": "Frank",
    "winner": "white",
    "status": "completed",
    "ended_at": "2025-03-17T09:15:00Z",
    "moves": [
      {"from": "e2", "to": "e4", "color": "white"},
      {"from": "c7", "to": "c5", "color": "black"},
      {"from": "g1", "to": "f3", "color": "white"},
      {"from": "d7", "to": "d6", "color": "black"}
    ]
  }
];
