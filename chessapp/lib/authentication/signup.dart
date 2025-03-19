// Flutter package imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:email_validator/email_validator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

// Project imports
import 'package:chessapp/components/button.dart';
import 'package:chessapp/components/constants.dart';
import '../components/textfield.dart';
import 'login.dart';

var logger = Logger();

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPage();
}

class _SignUpPage extends State<SignUpPage> {
  final TextEditingController playerIdController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  Map<String, dynamic> isValidPassword(String password) {
    if (password.length < 8) {
      return {
        "valid": false,
        "message": "Password must be at least 8 characters long."
      };
    }
    return {"valid": true, "message": ""};
  }

  void SignUserUp() async {
    String playerId = playerIdController.text;
    String password = passwordController.text;
    String email = emailController.text;
    logger.i('Player ID: $playerId');
    logger.i('Password: $password');
    logger.i('Player Email: $email');
    var passwordValidation = isValidPassword(password);

    if (playerId.isEmpty || password.isEmpty || email.isEmpty) {
      logger.i("All fields are required.");
      return;
    } else if (passwordValidation["valid"] as bool == false) {
      logger.i(passwordValidation["message"]);
      logger.i("Not valid Password");
      showErrorMessage("Not valid password");
    } else if (!EmailValidator.validate(email)) {
      logger.i("Not valid Email");
      showErrorMessage("Not valid Email");
    } else {
      try {
        final endpoint =
            "$BASE_URL/player/register?playerID=$playerId&email=$email&password=$password";
        final response = await http.post(Uri.parse(endpoint), headers: HEADERS);

        if (response.statusCode == 200) {
          logger.i("Registration successful!");
          _showSuccessPopup;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LogInPage()),
          );
        } else {
          showErrorMessage("Registration failed");
          logger.e("Registration failed.");
        }
      } catch (e) {
        showErrorMessage("Registration failed");
        logger.e("Error logging in: $e");
      }
    }
  }

  void _showSuccessPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        Future.delayed(const Duration(seconds: 3), () {
          Navigator.of(context).pop(); 
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: SizedBox(
            width: 300,
            height: 150,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Success Sign Up!",
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
                                "Sign Up",
                                style: GoogleFonts.dmSans(
                                  fontSize: 39,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(40, 40, 0, 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyTextField(
                                    controller: emailController,
                                    hintText: "Enter your email",
                                    obscureText: false,
                                    prefixIcon:
                                        const Icon(Icons.person_outline),
                                  ),
                                  const SizedBox(
                                    height: 18,
                                  ),
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
                              padding: const EdgeInsets.fromLTRB(115, 70, 0, 0),
                              child: Row(
                                children: [
                                  Text("Have an account?",
                                      style: GoogleFonts.dmSans(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        height: 1.2,
                                        letterSpacing: 0,
                                      )),
                                  TextButton(
                                    child: Text("Log In",
                                        style: GoogleFonts.dmSans(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            height: 1.2,
                                            letterSpacing: 0,
                                            color: HexColor("#44564A"))),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LogInPage(),
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
                      onPressed: SignUserUp,
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

/*
class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  Map<String, dynamic> isValidPassword(String password) {
    if (password.length < 8) {
      return {
        "valid": false,
        "message": "Password must be at least 8 characters long."
      };
    }
    return {"valid": true, "message": ""};
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController playerIdController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up to ChessLink'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: playerIdController,
              decoration: const InputDecoration(
                labelText: 'Player ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                String playerId = playerIdController.text;
                String password = passwordController.text;
                String email = emailController.text;
                print('Player ID: $playerId');
                print('Password: $password');
                print('Player Email: $email');

                if (playerId.isEmpty || password.isEmpty || email.isEmpty) {
                  print("All fields are required.");
                  return;
                }
                var passwordValidation = isValidPassword(password);
                if (passwordValidation["valid"] as bool == false) {
                  print(passwordValidation["message"]);
                  return;
                }

                try {
                  final endpoint =
                      "$BASE_URL/player/register?playerID=$playerId&email=$email&password=$password";
                  final response =
                      await http.post(Uri.parse(endpoint), headers: HEADERS);

                  if (response.statusCode == 200) {
                    print("Registration successful!");
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LogInPage()),
                    );
                  } else {
                    print("Registration failed.");
                  }
                } catch (e) {
                  print("Error logging in: $e");
                }
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}
*/
