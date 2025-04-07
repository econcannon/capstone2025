// Dart SDK imports
import 'dart:convert';

// External package imports
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

// Project imports
import '../../components/constants.dart';

var logger = Logger();

mixin StatsHandler {
  Future<Map<String, dynamic>?> fetchStats() async {
    try {
      final endpoint = "$BASE_URL/player/stats?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          return Map<String, dynamic>.from(data);
        }
      } else {
        logger.e("Failed to fetch stats. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching stats: $e");
    }
    return null;
  }

  // Future<List<Map<String, dynamic>>?> fetchGames() async {
  //   try {
  //     final response = await http.get(
  //         Uri.parse("$BASE_URL/player/game?playerID=$PLAYERID"),
  //         headers: HEADERS);

  //     if (response.statusCode == 200) {
  //       final data = json.decode(response.body);
  //       if (data != null && data["games"] != null) {
  //         return List<Map<String, dynamic>>.from(data["games"]);
  //       }
  //     } else {
  //       logger.e("Failed to fetch stats: ${response.body}");
  //     }
  //   } catch (e) {
  //     logger.e("Error fetching stats: $e");
  //   }
  //   return null;
  // }

  Future<Map<String, dynamic>?> fetchGames() async {
    try {
      final response = await http.get(
        Uri.parse("$BASE_URL/player/game?playerID=$PLAYERID"),
        headers: HEADERS,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data["games"] != null) {
          return Map<String, dynamic>.from(data);
        }
      } else {
        logger.e("Failed to fetch stats: ${response.body}");
      }
    } catch (e) {
      logger.e("Error fetching stats: $e");
    }
    return null;
  }
}
