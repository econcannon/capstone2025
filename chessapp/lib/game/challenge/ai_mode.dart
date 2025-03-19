import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

import 'package:chessapp/components/constants.dart';
import 'package:chessapp/game/chess.dart';
import 'package:chessapp/components/create_game.dart';
import 'package:chessapp/game/main_menu.dart';

class AIOption extends StatelessWidget with CreateGame {
  const AIOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HexColor("#D0B38B"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
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
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0), // Add horizontal padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDifficultyButton(context, "Easy", 1),
              const SizedBox(height: 20), // Even spacing
              _buildDifficultyButton(context, "Medium", 2),
              const SizedBox(height: 20), // Even spacing
              _buildDifficultyButton(context, "Hard", 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(BuildContext context, String difficulty, int depth) {
    return SizedBox(
      width: double.infinity, // Ensures all buttons are equal width
      height: 60, // Ensures all buttons are equal height
      child: ElevatedButton(
        onPressed: () async {
          final endpoint = Uri.parse(
              '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=$depth');

          if (await createGame(endpoint)) {
            print("Game created successfully");
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => GamePage(gameId: GAMEID)),
            );
          } else {
            print("Failed to create game");
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: HexColor("#44564A"), // Set button color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          difficulty,
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
