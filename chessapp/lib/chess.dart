import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:bishop/bishop.dart' as bishop;
import 'package:chessapp/main.dart';
import 'package:flutter/material.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:squares/squares.dart';

class GamePage extends StatefulWidget {
  final String gameId;

  const GamePage({super.key, required this.gameId});

  @override
  State<GamePage> createState() => _GamePage();
}

class _GamePage extends State<GamePage> {
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

      print('Connected to WebSocket');
      print("Connected to game ${widget.gameId} as $PLAYERID");

      isWebSocketConnected = true;

      webSocket.listen((message) {
        final decodedMessage = jsonDecode(message);
        print("Message received: $decodedMessage");

        if (decodedMessage["message_type"] == "game-state") {
          playerColor = decodedMessage["color"];
          String fen = decodedMessage["fen"];
          print("Game State Updated: $fen");
          setState(() {
            if (playerColor == "white") {
              player = Squares.white;
            } else {
              player = Squares.black;
            }
            game =
                bishop.Game(variant: bishop.Variant.standard());
            state = game.squaresState(player); 
          });
          print("You are playing as $playerColor");
          _updateGameState(fen);
        } else if (decodedMessage["message_type"] == "move") {
          final opponentMove = decodedMessage["move"];
          String opponentFrom = opponentMove["from"];
          String opponentTo = opponentMove["to"];
          print("Opponent moved: $opponentFrom to $opponentTo");

          String fen = decodedMessage["fen"];
          _updateGameState(fen);

          if (decodedMessage["turn"] == playerColor?[0]) {
            print("Your turn!");
          }
        } else if (decodedMessage["message_type"] == "confirmation") {
          String fen = decodedMessage["fen"];
          print("Move confirmed: $fen");
          _updateGameState(fen);
        } else if (decodedMessage["message_type"] == "error") {
          print("Illegal move: ${decodedMessage["error"]}");
        }
      }, onDone: () {
        print('WebSocket connection closed');
      }, onError: (error) {
        print('WebSocket error: $error');
      });
    } catch (e) {
      print('Error connecting to WebSocket: $e');
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

    print('Piece moved from $from to $to');

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
      print("Move sent: $from to $to");
    } catch (e) {
      print("Error sending move: $e");
    }
  }

  void _resetGame([bool ss = true]) {
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    if (ss) setState(() {});
  }

  void _flipBoard() => setState(() => flipBoard = !flipBoard);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Chess Game'),
        actions: [],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Game ID: $GAMEID'),
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
            const SizedBox(height: 32),
            OutlinedButton(
              onPressed: _resetGame,
              child: const Text('New Game'),
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
