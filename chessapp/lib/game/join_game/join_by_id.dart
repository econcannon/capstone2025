import 'package:flutter/material.dart';
import 'package:chessapp/game/chess.dart';
import 'package:chessapp/components/constants.dart';

class JoinGameWithID extends StatelessWidget {
  const JoinGameWithID({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController gameIdController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Game by ID'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: gameIdController,
              decoration: const InputDecoration(
                labelText: 'Game ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GAMEID = gameIdController.text;
                if (GAMEID.isEmpty) {
                  print("Error: Game ID is required.");
                  return;
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => GamePage(gameId: GAMEID)),
                );
              },
              child: const Text('Join Game'),
            ),
          ],
        ),
      ),
    );
  }
}
