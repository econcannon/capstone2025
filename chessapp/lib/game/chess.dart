// Dart SDK imports
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

// Flutter package imports
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
import 'package:chessapp/game/main_menu.dart';
import 'package:chessapp/components/create_game.dart';

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
  String? playerEmoji;
  String? opponentEmoji;
  Timer? emojiTimer;

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
          final fen = decodedMessage["fen"];
          final turn = decodedMessage["turn"];
          final move = decodedMessage["move"];

          if (fen == null || turn == null) {
            logger.e("Missing FEN or turn in move message: $decodedMessage");
            return;
          }

          _updateGameState(fen);

          if (move != null) {
            final from = move["from"];
            final to = move["to"];
            logger.i("Opponent moved: $from to $to");
          } else {
            logger.i("Move field missing — AI move");
          }

          if (turn == playerColor?[0]) {
            logger.i("Your turn!");
          }
        } else if (decodedMessage["message_type"] == "confirmation") {
          String fen = decodedMessage["fen"];
          logger.i("Move confirmed: $fen");
          _updateGameState(fen);
        } else if (decodedMessage["message_type"] == "player_message") {
          final emoji = decodedMessage["emoji"];
          final sender = decodedMessage["playerID"];

          logger.i("Emoji received from $sender: $emoji");

          setState(() {
            opponentEmoji = emoji;
          });
          _startEmojiTimer(isPlayer: false);
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

  void sendEmoji(String emojiName) {
    final message = jsonEncode({
      "message_type": "player-message",
      "playerID": PLAYERID,
      "emoji": emojiName, // should be "smiley", "sad", or "angry"
    });

    try {
      webSocket.add(message);
      logger.i("Emoji sent: $emojiName");
    } catch (e) {
      logger.e("Error sending emoji: $e");
    }
    setState(() {
      playerEmoji = emojiName;
    });
    _startEmojiTimer(isPlayer: true);
  }

  String getEmojiVisual(String emojiName) {
    switch (emojiName) {
      case 'smiley':
        return '😁';
      case 'sad':
        return '😢';
      case 'angry':
        return '😡';
      default:
        return '❓';
    }
  }

  void _startEmojiTimer({required bool isPlayer}) {
    emojiTimer?.cancel();
    emojiTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        if (isPlayer) {
          playerEmoji = null;
        } else {
          opponentEmoji = null;
        }
      });
    });
  }

  void _resetGame([bool ss = true]) async {
    game = bishop.Game(variant: bishop.Variant.standard());
    state = game.squaresState(player);
    if (ss) setState(() {});
  }

  void _flipBoard() => setState(() => flipBoard = !flipBoard);

  Widget _buildProfile(String name, {required bool isTop}) {
    final emojiName = isTop ? opponentEmoji : playerEmoji;
    final showEmoji = emojiName != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: HexColor("#44564A"),
                child: Text(
                  name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (showEmoji) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    getEmojiVisual(emojiName!),
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ],
            ],
          ),
          Text(
            name,
            style: GoogleFonts.dmSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isTop)
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: _showEmojiPicker,
            ),
        ],
      ),
    );
  }

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SizedBox(
          height: 150,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _emojiOption("smiley"),
              _emojiOption("sad"),
              _emojiOption("angry"),
            ],
          ),
        );
      },
    );
  }

  Widget _emojiOption(String emojiName) {
    return GestureDetector(
      onTap: () {
        sendEmoji(emojiName);
        Navigator.pop(context);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            getEmojiVisual(emojiName),
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 4),
          Text(emojiName),
        ],
      ),
    );
  }

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
      body: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildProfile("Opponent", isTop: true),
            Text(
              'Game ID: $GAMEID',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            Center(
              child: AspectRatio(
                aspectRatio: 1,
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
            ),
            _buildProfile(PLAYERID, isTop: false),
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
