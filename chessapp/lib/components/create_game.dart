import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chessapp/components/constants.dart';
import 'package:logger/logger.dart';

var logger = Logger();

mixin CreateGame {
  Future<bool> createGame(bool ai, Uri endpoint) async {
    try {
      logger.i(TOKEN);
      logger.i(HEADERS);

      final response = await http.post(endpoint, headers: HEADERS);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String gameId = data['gameID'];
        logger.i("New game created with ID: $gameId");
        GAMEID = gameId;
        return true;
      } else {
        logger.e("Failed to create game. Status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      logger.e("Error creating game: $e");
      return false;
    }
  }
}