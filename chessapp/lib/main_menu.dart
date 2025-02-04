import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart';

void updateHeaders(String TOKEN) {
  HEADERS['authorization'] = TOKEN;
}

class LogInPage extends StatelessWidget {
  const LogInPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController playerIdController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Log In'),
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
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                String playerId = playerIdController.text;
                String password = passwordController.text;
                print('Player ID: $playerId');
                print('Password: $password');

                if (playerId.isEmpty || password.isEmpty) {
                  print("Error: Player ID and Password are required.");
                  return;
                }

                try {
                  final endpoint =
                      "$BASE_URL/player/login?playerID=$playerId&password=$password";
                  final response =
                      await http.get(Uri.parse(endpoint), headers: HEADERS);

                  if (response.statusCode == 200) {
                    print("Welcome $playerId!");
                    final data = json.decode(response.body);
                    final token = data['token'];
                    print('Token: $token');
                    TOKEN = token;
                    PLAYERID = playerId;
                    PASSWORD = password;
                    updateHeaders(token);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const AuthMainMenu()),
                    );
                  } else {
                    print("Invalid username or password.");
                  }
                } catch (e) {
                  print("Error logging in: $e");
                }
              },
              child: const Text('Log In'),
            ),
          ],
        ),
      ),
    );
  }
}

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

class ResetPassword extends StatelessWidget {
  const ResetPassword({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController playerIdController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reset Password'),
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
                String email = emailController.text;
                print('Player ID: $playerId');
                print('Player Email: $email');

                if (playerId.isEmpty || email.isEmpty) {
                  print("All fields are required.");
                  return;
                }

                try {
                  final endpoint =
                      "$BASE_URL/player/reset-password?playerID=$playerId&email=$email";
                  final response =
                      await http.post(Uri.parse(endpoint), headers: HEADERS);

                  print(
                      "Response status code: ${response.statusCode}"); // Log status code
                  print("Response body: ${response.body}"); // Log response body

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    final token = data['token'];
                    print('Token: $token');
                    TOKEN = token;
                    PLAYERID = playerId;
                    updateHeaders(token);
                    print("Password reset email sent.");
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) =>
                    //         ResetPasswordPage(),
                    //   ),
                    // );
                  } else {
                    print("Password reset failed.");
                  }
                } catch (e) {
                  print("Error resetting password: $e");
                }
              },
              child: const Text('Reset Password'),
            ),
          ],
        ),
      ),
    );
  }
}

class ResetPasswordPage extends StatelessWidget {
  ResetPasswordPage({super.key});
  final Uri resetLink = Uri.parse('https://thtran13.github.io/ChessLink/');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            if (await canLaunchUrl(resetLink)) {
              await launchUrl(resetLink); // Opens the link in the browser
            } else {
              throw 'Could not launch $resetLink';
            }
          },
          child: const Text('Reset Password'),
        ),
      ),
    );
  }
}
