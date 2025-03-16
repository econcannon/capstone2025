// Dart SDK imports
import 'dart:convert';

// Flutter package imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

// Project imports
import 'package:chessapp/authentication/signup.dart';
import 'package:chessapp/components/button.dart';
import 'package:chessapp/components/constants.dart';
import 'package:chessapp/game/main_menu.dart';
import '../components/textfield.dart';

var logger = Logger();

class LogInPage extends StatefulWidget {
  const LogInPage({super.key});

  void updateHeaders(String TOKEN) {
    HEADERS['authorization'] = TOKEN;
  }

  @override
  State<LogInPage> createState() => _LogInPage();
}

class _LogInPage extends State<LogInPage> {
  final TextEditingController playerIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  void updateHeaders(String TOKEN) {
    HEADERS['authorization'] = TOKEN;
  }

  void SignUserIn() async {
    String playerId = playerIdController.text;
    String password = passwordController.text;
    try {
      final endpoint =
          "$BASE_URL/player/login?playerID=$playerId&password=$password";
      final response = await http.get(Uri.parse(endpoint), headers: HEADERS);

      if (response.statusCode == 200) {
        logger.i("Welcome $playerId!");
        final data = json.decode(response.body);
        final token = data['token'];
        logger.i('Token: $token');
        TOKEN = token;
        PLAYERID = playerId;
        PASSWORD = password;
        updateHeaders(token);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) =>  const MainMenu()),
        );
      } else {
        logger.e("Invalid username or password.");
        showErrorMessage("Invalid username or password.");
      }
    } catch (e) {
      showErrorMessage("Invalid username or password.");
      logger.e("Error logging in: $e");
    }
  }

  void showErrorMessage(String message) {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.red,
            content: Container(
              width: 300,
              height: 16,
              child: Center(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: Colors.black,
          onPressed: () {
            Navigator.of(context).popUntil((route) => route.isFirst);
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
      resizeToAvoidBottomInset: false,
      backgroundColor: HexColor("#D0B38B"),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(0, 377, 0, 0),
        shrinkWrap: true,
        reverse: true,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Stack(
                children: [
                  Container(
                    height: 540,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: HexColor("#ffffff"),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40),
                        topRight: Radius.circular(40),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 30, 0, 0),
                              child: Text(
                                "Log In",
                                style: GoogleFonts.dmSans(
                                  fontSize: 39,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 62, 0, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyTextField(
                                    controller: playerIdController,
                                    hintText: "Enter your player ID",
                                    obscureText: false,
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                  ),
                                  const SizedBox(
                                    height: 18,
                                  ),
                                  MyTextField(
                                    controller: passwordController,
                                    hintText: "Enter your password",
                                    obscureText: true,
                                    prefixIcon: const Icon(Icons.lock_outline),
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(87, 120, 0, 0),
                              child: Row(
                                children: [
                                  Text("Don't have an account? ",
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                        letterSpacing: 0,
                                      )),
                                  TextButton(
                                    child: Text("Sign Up",
                                        style: GoogleFonts.dmSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                            letterSpacing: 0,
                                            color: HexColor("#44564A"))),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const SignUpPage(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 320, 0, 18),
                    child: MyButton(
                      onPressed: SignUserIn,
                      buttonText: 'Submit',
                    ),
                  ),
                  Transform.translate(
                    offset: const Offset(0, -192),
                    child: Center(
                      child: Image.asset(
                        'assets/login.png',
                        width: 278,
                        height: 203,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}
