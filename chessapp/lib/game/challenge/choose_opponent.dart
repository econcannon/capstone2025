// Flutter SDK imports
import 'package:flutter/material.dart';

// External package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:logger/logger.dart';

// Project-specific imports
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/components/create_game.dart';
import 'package:chessapp/game/chess.dart';
import 'ai_mode.dart';

var logger = Logger();

class PlayOption extends StatefulWidget {
  const PlayOption({super.key});

  @override
  State<PlayOption> createState() => _PlayOptionState();
}

class _PlayOptionState extends State<PlayOption> with CreateGame {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: HexColor("#D0B38B"),
      title: Text(
        'Choose Your Opponent',
        textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      content: Container(
        width: 350,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          color: HexColor("#D0B38B"),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildOptionCard(
                context,
                "Players",
                Icons.people,
                HexColor('#44564A'),
                () async {
                  final endpoint = Uri.parse(
                      '$BASE_URL/create?playerID=$PLAYERID&ai=false&depth=1');

                  final gameId = await createGame(endpoint);
                  if (gameId != null) {
                    logger.i("Game created successfully");
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => GamePage(gameId: GAMEID)),
                      );
                    }
                  } else {
                    logger.e("Failed to create game");
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOptionCard(
                context,
                "AI",
                Icons.computer,
                HexColor('#44564A'),
                () {
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AIOption()),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard(BuildContext context, String title, IconData icon,
      Color iconColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        child: SizedBox(
          width: 140,
          height: 120,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: iconColor),
                const SizedBox(height: 10),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
