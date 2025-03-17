import 'package:flutter/material.dart';
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/components/create_game.dart';
import 'package:chessapp/game/chess.dart';
import 'ai_mode.dart';

class PlayOption extends StatelessWidget with CreateGame {
  const PlayOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Your Opponents'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () async {
                  final endpoint = Uri.parse(
                      '$BASE_URL/create?playerID=$PLAYERID&ai=false&depth=1');

                  if (await createGame(true, endpoint)) {
                    print("Game created successfully");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GamePage(gameId: GAMEID)),
                    );
                  } else {
                    print("Failed to create game");
                  }
                },
                child: const Text('Players'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AIOption()),
                  );
                },
                child: const Text('AI'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Back to Main Menu'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}