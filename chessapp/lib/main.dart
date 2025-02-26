import 'package:flutter/material.dart';
import 'chess.dart';
import 'main_menu.dart';
import 'manage_game.dart';
import 'friends.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'testBluetooth.dart';

String PLAYERID = "";
String PASSWORD = "";
String TOKEN = "";
String GAMEID = "";

String BASE_URL = "https://chess-app-v5.concannon-e.workers.dev";
int PORT = 443;
Map<String, String> HEADERS = {
  "Content-Type": "application/json",
};

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chess Link',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

void main() => runApp(const MyApp());

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ButtonPage()),
        );
      },
      child: Scaffold(
        body: Center(
          child: Text(
            'Welcome to Chess Link',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
        ),
      ),
    );
  }
}

class ButtonPage extends StatelessWidget {
  const ButtonPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessLink Menu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const BlueToothPage()),
                  );
                },
                child: const Text('test'), //done
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LogInPage()),
                  );
                },
                child: const Text('Log In'), //done
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SignUpPage()),
                    //MaterialPageRoute(builder: (context) => const SignUp()),
                  );
                },
                child: const Text('Sign Up'), //done
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ResetPassword()),
                  );
                },
                child: const Text(
                    'Reset Password'), //implemented, does not work yet
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Exit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthMainMenu extends StatelessWidget {
  const AuthMainMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ChessLink Menu'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const FriendsPage()),
                  );
                },
                child: const Text('Manage Friends'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ManageGame()),
                  );
                },
                child: const Text('Manage Games'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ManageGame extends StatelessWidget {
  const ManageGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Games'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlayOption()),
                  );
                },
                child: const Text('Create New Game'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JoinGame(),
                      ));
                },
                child: const Text('Join Game'),
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

class JoinGame extends StatelessWidget {
  const JoinGame({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Games'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JoinGameWithID(),
                      ));
                },
                child: const Text('Join Game by ID'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {},
                child: const Text('Join Public Game'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            ViewOngoingGame(playerId: PLAYERID)),
                  );
                },
                child: const Text('Join Your Ongoing Games'),
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

class AIOption extends StatelessWidget with CreateGame {
  const AIOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI difficulties'),
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
                      '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

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
                child: const Text('Easy'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () async {
                  final endpoint = Uri.parse(
                      '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

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
                child: const Text('Medium'),
              ),
            ),
            SizedBox(
              width: 300,
              child: ElevatedButton(
                onPressed: () async {
                  final endpoint = Uri.parse(
                      '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

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
                child: const Text('Hard'),
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
