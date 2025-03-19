import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../components/constants.dart';
import 'package:logger/logger.dart';

var logger = Logger();

/*
mixin StatsHandler {
  StatsService _statsService = StatsService();
  StatsModel? stats;

  Future<void> loadStats() async {
    stats = await _statsService.fetchStats();
  }

  Map<String, dynamic> getSelectedStats(String category, String difficulty) {
    if (stats == null) return {};
    
    if (category == "All Matches") {
      return stats!.allMatches;
    } else if (category == "Player Matches") {
      return stats!.playerMatches;
    } else if (category == "AI Matches") {
      return stats!.aiMatches[difficulty] ?? {};
    }
    
    return {};
  }
}

class StatsService {
  Future<StatsModel?> fetchStats() async {
    try {
      final endpoint = "$BASE_URL/player/stats?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          return StatsModel.fromJson(data);
        }
      } else {
        logger.e("Failed to fetch stats.");
      }
    } catch (e) {
      logger.e("Error fetching stats: $e");
    }
    return null;
  }
}

class StatsModel {
  final Map<String, dynamic> allMatches;
  final Map<String, dynamic> playerMatches;
  final Map<String, Map<String, dynamic>> aiMatches;

  StatsModel({
    required this.allMatches,
    required this.playerMatches,
    required this.aiMatches,
  });

  factory StatsModel.fromJson(Map<String, dynamic> json) {
    return StatsModel(
      allMatches: json["allMatches"] ?? {},
      playerMatches: json["playerMatches"] ?? {},
      aiMatches: json["aiMatches"] ?? {},
    );
  }
}
*/

mixin StatsHandler {
  Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final endpoint = "$BASE_URL/player/stats?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['stats'] != null) {
          return Map<String, dynamic>.from(data['stats']);
        }
      } else {
        logger.e("Failed to fetch stats. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching stats: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> fetchGames() async {
    try {
      final response = await http.get(Uri.parse("$BASE_URL/player/game?gameId=$GAMEID"), headers: HEADERS);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          return data.map((game) => Map<String, dynamic>.from(game)).toList();
        } else {
          logger.e("No games found for the player.");
        }
      } else {
        logger.e("Failed to load games. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching games: $e");
    }
    return null;
  }

}