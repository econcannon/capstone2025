import 'package:flutter/material.dart';
import 'package:chessapp/components/constants.dart';

class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key});

  @override
  _PlayerStatsScreenState createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  @override
  void initState() {
    super.initState();
    //fetchStats();
  }

  // Future<void> fetchStats() async {
  //   final stats = await ...
  //   setState(() {
  //     playerStats = stats;
  //     isLoading = false;
  //   });
  // }

  @override
  Widget build(BuildContext context) {
    // Dummy stats data
    final Map<String, dynamic> playerStats = {
      "gamesPlayed": 25,
      "wins": 15,
      "losses": 7,
      "ties": 3,
      "movesPerGame": 28,
    };

    return Scaffold(
      appBar: AppBar(title: const Text("Player Stats")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Player ID: ${playerStats[PLAYERID]}",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 20),

            // Stats List
            Expanded(
              child: ListView(
                children: [
                  buildStatCard("Games Played", playerStats["gamesPlayed"]),
                  buildStatCard("Wins", playerStats["wins"]),
                  buildStatCard("Losses", playerStats["losses"]),
                  buildStatCard("Ties", playerStats["ties"]),
                  buildStatCard("Moves/Game", playerStats["movesPerGame"]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStatCard(String title, int value) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(value.toString(), style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
