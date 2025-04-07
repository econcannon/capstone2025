// Flutter package imports
import 'package:chessapp/components/create_game.dart';
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:logger/logger.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Project imports
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/components/menu_button.dart';
import 'package:chessapp/components/popup_menu.dart';
import 'package:chessapp/game/main_menu_component/game_list.dart';
//import 'package:chessapp/game/main_menu_component/player_stats.dart';
import 'package:chessapp/game/main_menu_component/side_menu.dart';
import 'package:chessapp/game/challenge/choose_opponent.dart';
import 'package:chessapp/game/chess.dart';
//import 'package:chessapp/old_challenge_friends.dart';

var logger = Logger();

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  _MainMenu createState() => _MainMenu();
}

class _MainMenu extends State<MainMenu> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      endDrawer: const SideMenu(),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: HexColor("#D0B38B"),
        title: Text(
          "Chess Link",
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: CircleAvatar(
                backgroundColor: HexColor('#44564A'),
                child: Text(
                  PLAYERID[0],
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              onPressed: () {
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                width: 332,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return const PlayOption();
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HexColor("#B58763"),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 28),
                  ),
                  child: Text(
                    'Create New Game',
                    style: GoogleFonts.dmSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            // BuildMenuButton(
            //   label: 'Join Game by ID',
            //   onPressed: () async {
            //     showDialog<String>(
            //       context: context,
            //       builder: (context) => InputDialog(
            //         title: "Enter Game ID",
            //         hintText: "Game ID",
            //         buttonText: "Join",
            //         onConfirm: (gameId) {
            //           Navigator.of(context).pop(gameId);
            //         },
            //       ),
            //     ).then((gameId) {
            //       final endpoint = Uri.parse(
            //           '$BASE_URL/create?playerID=$PLAYERID&ai=false&depth=1');

            //       final gameId = await JoinGame(endpoint);
            //       if (gameId) {
            //         logger.i("Game created successfully");
            //         if (mounted) {
            //           Navigator.pop(context);
            //           Navigator.push(
            //             context,
            //             MaterialPageRoute(
            //                 builder: (context) => GamePage(gameId: GAMEID)),
            //           );
            //         }
            //       } else {
            //         logger.e("Failed to create game");
            //       }
            //     });
            //   },
            // ),
            BuildMenuButton(
              label: 'Join Game by ID',
              onPressed: () async {
                final gameId = await showDialog<String>(
                  context: context,
                  builder: (context) => InputDialog(
                    title: "Enter Game ID",
                    hintText: "Game ID",
                    buttonText: "Join",
                    onConfirm: (gameId) {
                      Navigator.of(context).pop(gameId);
                    },
                  ),
                );

                if (gameId != null && gameId.isNotEmpty) {
                  GAMEID = gameId;
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
                          content:
                              Text("Failed to join game: ${response.body}"),
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
                }
              },
            ),
            // BuildMenuButton(
            //   label: 'Join Public Game',
            //   onPressed: () {},
            // ),
            BuildMenuButton(
              label: 'View Your Ongoing Games',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ViewOngoingGame(playerId: PLAYERID),
                  ),
                );
              },
            ),
            // BuildMenuButton(
            //   label: 'Friends',
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const FriendsPage(),
            //       ),
            //     );
            //   },
            // ),
            // BuildMenuButton(
            //   label: 'Testing Stats Page',
            //   onPressed: () {
            //     Navigator.push(
            //       context,
            //       MaterialPageRoute(
            //         builder: (context) => const PlayerStatsScreen(),
            //       ),
            //     );
            //   },
            // ),
            BuildMenuButton(
              label: 'Log out',
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }
}
