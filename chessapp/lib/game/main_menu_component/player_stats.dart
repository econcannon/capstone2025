// Flutter package imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:logger/logger.dart';

// Project imports
import 'package:chessapp/game/get_data/stats.dart';
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/game/main_menu_component/game_stats.dart';
import 'package:chessapp/game/main_menu.dart';

var logger = Logger();

class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key});

  @override
  _PlayerStatsScreenState createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen>
    with StatsHandler {
  Map<String, dynamic> playerStats = {};

  @override
  void initState() {
    super.initState();
    fetchAndSetStats();
  }

  Future<void> fetchAndSetStats() async {
    final stats = await fetchStats();
    logger.i("fetching stats");

    if (stats != null) {
      setState(() {
        print("setting state");
        playerStats = stats;
      });
      printPlayerStatsTable();
    }
    else{
      print("stats is null");
    }
  }

  void printPlayerStatsTable() {
    print("Player Stats:");
    playerStats.forEach((key, value) {
      print("$key: $value");
    });
  }

  // final Map<String, dynamic> playerStats = {
  //   "gamesPlayed": 25,
  //   "wins": 15,
  //   "losses": 7,
  //   "ties": 3,
  //   "movesPerGame": 28,
  // };

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
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Player Stats Box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: HexColor("#EDEDED"),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildStatRow("Player ID", PLAYERID),
                  const Divider(thickness: 1, color: Colors.black26),
                  buildStatRow(
                      "Games Played", playerStats["games_played"] ?? 0),
                  buildStatRow("Wins", playerStats["wins"] ?? 0),
                  buildStatRow("Losses", playerStats["losses"] ?? 0),
                  buildStatRow("Ties", playerStats["ties"] ?? 0),
                  buildStatRow(
                      "Moves/Game", playerStats["moves_per_game"] ?? 0),
                  buildStatRow("Rating", playerStats["rating"] ?? 0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GameStatsScreen(),
          ),
        ],
      ),
    );
  }

  Widget buildStatRow(String title, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0,
              color: Colors.black,
            ),
          ),
          Text(
            value.toString(),
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.2,
              letterSpacing: 0,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

/*
class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key});

  @override
  _PlayerStatsScreenState createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  String _selectedCategory = "All Matches"; 
  String? _selectedAIDifficulty;
  bool _showAIDropdown = false; 

  // Dummy stats data
  final Map<String, dynamic> allMatchesStats = {
    "gamesPlayed": 25,
    "wins": 15,
    "losses": 7,
    "ties": 3,
    "movesPerGame": 28,
  };

  final Map<String, dynamic> playerMatchesStats = {
    "gamesPlayed": 12,
    "wins": 8,
    "losses": 3,
    "ties": 1,
    "movesPerGame": 30,
  };

  final Map<String, Map<String, dynamic>> aiMatchesStats = {
    "Easy": {
      "gamesPlayed": 5,
      "wins": 3,
      "losses": 2,
      "ties": 0,
      "movesPerGame": 25,
    },
    "Normal": {
      "gamesPlayed": 4,
      "wins": 2,
      "losses": 1,
      "ties": 1,
      "movesPerGame": 27,
    },
    "Hard": {
      "gamesPlayed": 4,
      "wins": 2,
      "losses": 2,
      "ties": 0,
      "movesPerGame": 29,
    },
  };

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> selectedStats = _getSelectedStats();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Player Stats"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdownMenu(),

            const SizedBox(height: 10),

            Text("Player ID: $PLAYERID",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),

            const SizedBox(height: 10),
            if (_showAIDropdown) _buildAIDifficultyDropdown(),

            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: selectedStats.entries.map((entry) {
                  return buildStatCard(entry.key, entry.value);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text(
          "Stats Type: ",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: DropdownButton<String>(
              value: _selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue!;
                  _showAIDropdown = _selectedCategory == "AI Matches";
                  _selectedAIDifficulty = _showAIDropdown ? "Easy" : null;
                });
              },
              isExpanded: true,
              items: <String>["All Matches", "AI Matches", "Player Matches"]
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              underline: const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAIDifficultyDropdown() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        const Text("AI Difficulty: ",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
            child: DropdownButton<String>(
              value: _selectedAIDifficulty,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedAIDifficulty = newValue;
                });
              },
              isExpanded: true,
              items: <String>["Easy", "Normal", "Hard"]
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: const TextStyle(fontSize: 16)),
                );
              }).toList(),
              underline: const SizedBox(),
            ),
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getSelectedStats() {
    if (_selectedCategory == "All Matches") {
      return allMatchesStats;
    } else if (_selectedCategory == "Player Matches") {
      return playerMatchesStats;
    } else if (_selectedCategory == "AI Matches" && _selectedAIDifficulty != null) {
      return aiMatchesStats[_selectedAIDifficulty!] ?? {};
    }
    return {};
  }

  Widget buildStatCard(String title, dynamic value) {
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
*/
