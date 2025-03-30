import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'package:chessapp/components/constants.dart';
var logger = Logger();

mixin CreateGame {
  Future<String?> createGame(Uri endpoint) async {
    try {
      logger.i(TOKEN);
      logger.i(HEADERS);

      final response = await http.post(endpoint, headers: HEADERS);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String gameId = data['gameID'];
        logger.i("New game created with ID: $gameId");
        GAMEID = gameId;
        return gameId;
      } else {
        logger.e("Failed to create game. Status code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      logger.e("Error creating game: $e");
      return null;
    }
  }
}
