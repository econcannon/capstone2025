// Flutter package imports
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

// Project imports
import 'package:chessapp/game/get_data/friends.dart';
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/game/chess.dart';

var logger = Logger();

class ChallengeListener extends StatefulWidget {
  final Widget child;
  const ChallengeListener({required this.child, Key? key}) : super(key: key);

  @override
  State<ChallengeListener> createState() => _ChallengeListenerState();
}

class _ChallengeListenerState extends State<ChallengeListener>
    with FriendsHandler {
  Timer? _pollingTimer;
  final Map<String, DateTime> _ignoredChallenges = {};
  String firstGame = "";

  @override
  void initState() {
    super.initState();
    _pollingTimer =
        Timer.periodic(Duration(seconds: 5), (_) => _checkChallenges());
  }

  void _fetchFirstGame() async {
    try {
      final endpoint = "$BASE_URL/player/games?playerID=$PLAYERID";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['games'] != null && data['games'].isNotEmpty) {
          setState(() {
            Map<String, dynamic> getGame = Map<String, dynamic>.from(data['games'][0]);
            firstGame = getGame[0];
          });
          logger.i("First game fetched successfully: $firstGame");
        } else {
          logger.e("No games found.");
        }
      } else {
        logger.e("Failed to fetch games. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      logger.e("Error fetching first game: $e");
    }
  }

  Future<void> _checkChallenges() async {
  await fetchChallenges();

  final now = DateTime.now();
  for (final friendId in incomingChallenges) {
    // Skip if recently declined
    if (_ignoredChallenges.containsKey(friendId)) {
      final lastIgnored = _ignoredChallenges[friendId]!;
      if (now.difference(lastIgnored).inMinutes < 3) {
        continue; // skip this challenge for now
      } else {
        _ignoredChallenges.remove(friendId); // timeout expired
      }
    }

    _showChallengeDialog(friendId);
    break;
  }
}

  void _showChallengeDialog(String friendId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Challenge Received"),
        content: Text("Your friend $friendId challenged you to a game!"),
        actions: [
          TextButton(
            onPressed: () {
              _ignoredChallenges[friendId] = DateTime.now();
              Navigator.of(context).pop();
            },
            child: Text("Decline"),
          ),
          ElevatedButton(
            onPressed: () async {
              await acceptChallenge(friendId);
              GAMEID = firstGame;
              final endpoint =
                  "$BASE_URL/player/join-game?playerID=$PLAYERID&gameID=$GAMEID&ai=false&depth=1";

              try {
                final response =
                    await http.get(Uri.parse(endpoint), headers: HEADERS);
                logger.i(HEADERS);

                if (response.statusCode == 200) {
                  final data = json.decode(response.body);
                  logger.i("Game joined successfully: $data");

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GamePage(gameId: GAMEID),
                    ),
                  );
                } else {
                  logger.e(
                      "Failed to join game. Status Code: ${response.statusCode}");
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Error"),
                      content: Text("Failed to join game: ${response.body}"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text("OK"),
                        ),
                      ],
                    ),
                  );
                }
              } catch (e) {
                logger.e("Error joining game: $e");
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Error"),
                    content: Text("An error occurred: $e"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
            },
            child: Text("Accept"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
