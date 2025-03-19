// Dart SDK imports
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

// Flutter package imports
import 'package:chessapp/components/create_game.dart';
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:bishop/bishop.dart' as bishop;
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

// Project imports
import '../components/constants.dart';
import 'package:chessapp/components/button.dart';
import 'package:chessapp/game/main_menu.dart';

var logger = Logger();

class GamePage extends StatefulWidget {
  final String gameId;

  const GamePage({super.key, required this.gameId});

  @override
  State<GamePage> createState() => _GamePage();
}

class _GamePage extends State<GamePage> with CreateGame {
  late bishop.Game game;
  late SquaresState state;
  late io.WebSocket webSocket;
  int player = Squares.white;
  bool flipBoard = false;
  bool isWebSocketConnected = false;
  String? playerColor;

  @override
  void initState() {
    super.initState();
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    _initializeWebSocketConnection();
  }

  Future<void> _initializeWebSocketConnection() async {
    await connectToWebSocket();
    if (isWebSocketConnected) {
      _resetGame(false);
    }
  }

  Future<void> connectToWebSocket() async {
    try {
      webSocket = await io.WebSocket.connect(
        'wss://chess-app-v5.concannon-e.workers.dev/connect?gameID=${widget.gameId}&playerID=$PLAYERID',
      );

      logger.i('Connected to WebSocket');
      logger.i("Connected to game ${widget.gameId} as $PLAYERID");

      isWebSocketConnected = true;

      webSocket.listen((message) {
        final decodedMessage = jsonDecode(message);
        logger.i("Message received: $decodedMessage");

        if (decodedMessage["message_type"] == "game-state") {
          playerColor = decodedMessage["color"];
          String fen = decodedMessage["fen"];
          logger.i("Game State Updated: $fen");
          setState(() {
            if (playerColor == "white") {
              player = Squares.white;
            } else {
              player = Squares.black;
            }
            game = bishop.Game(variant: bishop.Variant.standard());
            state = game.squaresState(player);
          });
          logger.i("You are playing as $playerColor");
          _updateGameState(fen);
        } else if (decodedMessage["message_type"] == "move") {
          final opponentMove = decodedMessage["move"];
          String opponentFrom = opponentMove["from"];
          String opponentTo = opponentMove["to"];
          logger.i("Opponent moved: $opponentFrom to $opponentTo");

          String fen = decodedMessage["fen"];
          _updateGameState(fen);

          if (decodedMessage["turn"] == playerColor?[0]) {
            logger.i("Your turn!");
          }
        } else if (decodedMessage["message_type"] == "confirmation") {
          String fen = decodedMessage["fen"];
          logger.i("Move confirmed: $fen");
          _updateGameState(fen);
        } else if (decodedMessage["message_type"] == "error") {
          logger.e("Illegal move: ${decodedMessage["error"]}");
        }
      }, onDone: () {
        logger.i('WebSocket connection closed');
      }, onError: (error) {
        logger.e('WebSocket error: $error');
      });
    } catch (e) {
      logger.e('Error connecting to WebSocket: $e');
      isWebSocketConnected = false;
    }
  }

  void _updateGameState(String fen) {
    setState(() {
      game.loadFen(fen);
      state = game.squaresState(player);
    });
  }

  Future<void> _onMove(Move move) async {
    String squareToAlgebraic(int square) {
      int row = square ~/ 8;
      int col = square % 8;
      String file = String.fromCharCode('a'.codeUnitAt(0) + col);
      String rank = (8 - row).toString();
      return file + rank;
    }

    String from = squareToAlgebraic(move.from);
    String to = squareToAlgebraic(move.to);

    logger.i('Piece moved from $from to $to');

    final moveMessage = jsonEncode({
      "message_type": "move",
      "playerID": PLAYERID,
      "move": {
        "from": from,
        "to": to,
      },
    });

    try {
      webSocket.add(moveMessage);
      logger.i("Move sent: $from to $to");
    } catch (e) {
      logger.e("Error sending move: $e");
    }
  }

  void _resetGame([bool ss = true]) async {
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    if (ss) setState(() {});
  }

  void _flipBoard() => setState(() => flipBoard = !flipBoard);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: HexColor("#44564A"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.white,
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
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Game ID: $GAMEID',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(4.0),
              child: BoardController(
                state: flipBoard ? state.board.flipped() : state.board,
                playState: state.state,
                pieceSet: PieceSet.merida(),
                theme: BoardTheme.brown,
                moves: state.moves,
                onMove: _onMove,
                onPremove: _onMove,
                markerTheme: MarkerTheme(
                  empty: MarkerTheme.dot,
                  piece: MarkerTheme.corners(),
                ),
                promotionBehaviour: PromotionBehaviour.autoPremove,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: MyButton(
                onPressed: () async {
                  setState(() {});
                  final endpoint = Uri.parse(
                      '$BASE_URL/create?playerID=$PLAYERID&ai=false&depth=1');

                  if (await createGame(endpoint)) {
                    logger.i("Game created successfully");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GamePage(gameId: GAMEID)),
                    );
                  } else {
                    logger.e("Failed to create game");
                  }
                },
                buttonText: 'New Game',
              ),
            ),
            IconButton(
              onPressed: _flipBoard,
              icon: const Icon(Icons.rotate_left),
            ),
          ],
        ),
      ),
    );
  }
}
