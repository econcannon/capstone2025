import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:get/get.dart';
import 'package:chessapp/authentication/login.dart';
import 'package:google_fonts/google_fonts.dart';

// mixin CreateGame {
//   Future<bool> createGame(bool ai, Uri endpoint) async {
//     try {
//       print(TOKEN);
//       print(HEADERS);

//       final response = await http.post(endpoint, headers: HEADERS);
//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         String gameId = data['gameID'];
//         print("New game created with ID: $gameId");
//         GAMEID = gameId;
//         return true;
//       } else {
//         print("Failed to create game. Status code: ${response.statusCode}");
//         return false;
//       }
//     } catch (e) {
//       print("Error creating game: $e");
//       return false;
//     }
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Chess Link',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
//         useMaterial3: true,
//       ),
//       home: const HomePage(),
//     );
//   }
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chess Link',
      theme: ThemeData().copyWith(
        colorScheme: ThemeData().colorScheme.copyWith(
              primary: HexColor("#44564A"),
            ),
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
          MaterialPageRoute(builder: (context) => const LogInPage()),
        );
      },
      child: Scaffold(
        backgroundColor: HexColor("#D0B38B"),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/login.png',
                width: 278,
                height: 203,
              ),
              const SizedBox(height: 20),
              Text(
                'Chess Link',
                style: GoogleFonts.dmSans(
                  fontSize: 39,
                  fontWeight: FontWeight.w700,
                  height: 1.2, 
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class LogInMenuPage extends StatelessWidget {
//   const LogInMenuPage({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('ChessLink Menu'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                 },
//                 child: const Text('test'), //done
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const LogInPage()),
//                   );
//                 },
//                 child: const Text('Log In'), //done
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const SignUpPage()),
//                   );
//                 },
//                 child: const Text('Sign Up'), //done
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) => const ResetPassword()),
//                   );
//                 },
//                 child: const Text(
//                     'Reset Password'), //implemented, does not work yet
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.pop(context);
//                 },
//                 child: const Text('Exit'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
// class MainMenu extends StatelessWidget {
//   const MainMenu({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('ChessLink Menu'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const FriendsPage()),
//                   );
//                 },
//                 child: const Text('Manage Friends'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const PlayOption()),
//                   );
//                 },
//                 child: const Text('Create New Game'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => JoinGame(),
//                       ));
//                 },
//                 child: const Text('Join Game'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).popUntil((route) => route.isFirst);
//                 },
//                 child: const Text('Logout'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class JoinGame extends StatelessWidget {
//   const JoinGame({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Join Games'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => JoinGameWithID(),
//                       ));
//                 },
//                 child: const Text('Join Game by ID'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {},
//                 child: const Text('Join Public Game'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(
//                         builder: (context) =>
//                             ViewOngoingGame(playerId: PLAYERID)),
//                   );
//                 },
//                 child: const Text('Join Your Ongoing Games'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).popUntil((route) => route.isFirst);
//                 },
//                 child: const Text('Back to Main Menu'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class PlayOption extends StatelessWidget with CreateGame {
//   const PlayOption({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Choose Your Opponents'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final endpoint = Uri.parse(
//                       '$BASE_URL/create?playerID=$PLAYERID&ai=false&depth=1');

//                   if (await createGame(true, endpoint)) {
//                     print("Game created successfully");
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => GamePage(gameId: GAMEID)),
//                     );
//                   } else {
//                     print("Failed to create game");
//                   }
//                 },
//                 child: const Text('Players'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.push(
//                     context,
//                     MaterialPageRoute(builder: (context) => const AIOption()),
//                   );
//                 },
//                 child: const Text('AI'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).popUntil((route) => route.isFirst);
//                 },
//                 child: const Text('Back to Main Menu'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class AIOption extends StatelessWidget with CreateGame {
//   const AIOption({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('AI difficulties'),
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final endpoint = Uri.parse(
//                       '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

//                   if (await createGame(true, endpoint)) {
//                     print("Game created successfully");
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => GamePage(gameId: GAMEID)),
//                     );
//                   } else {
//                     print("Failed to create game");
//                   }
//                 },
//                 child: const Text('Easy'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final endpoint = Uri.parse(
//                       '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

//                   if (await createGame(true, endpoint)) {
//                     print("Game created successfully");
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => GamePage(gameId: GAMEID)),
//                     );
//                   } else {
//                     print("Failed to create game");
//                   }
//                 },
//                 child: const Text('Medium'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () async {
//                   final endpoint = Uri.parse(
//                       '$BASE_URL/create?playerID=$PLAYERID&ai=true&depth=1');

//                   if (await createGame(true, endpoint)) {
//                     print("Game created successfully");
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                           builder: (context) => GamePage(gameId: GAMEID)),
//                     );
//                   } else {
//                     print("Failed to create game");
//                   }
//                 },
//                 child: const Text('Hard'),
//               ),
//             ),
//             SizedBox(
//               width: 300,
//               child: ElevatedButton(
//                 onPressed: () {
//                   Navigator.of(context).popUntil((route) => route.isFirst);
//                 },
//                 child: const Text('Back to Main Menu'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
