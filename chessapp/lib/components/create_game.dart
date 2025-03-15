import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:chessapp/components/constants.dart';

mixin CreateGame {
  Future<bool> createGame(bool ai, Uri endpoint) async {
    try {
      print(TOKEN);
      print(HEADERS);

      final response = await http.post(endpoint, headers: HEADERS);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String gameId = data['gameID'];
        print("New game created with ID: $gameId");
        GAMEID = gameId;
        return true;
      } else {
        print("Failed to create game. Status code: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error creating game: $e");
      return false;
    }
  }
}