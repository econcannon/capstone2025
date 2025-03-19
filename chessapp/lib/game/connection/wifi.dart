import 'package:flutter/material.dart';

class EnterWifiInfoPage extends StatefulWidget {
  final Function(String ssid, String password) onWifiInfoSubmitted;

  const EnterWifiInfoPage({super.key, required this.onWifiInfoSubmitted});

  @override
  _EnterWifiInfoPageState createState() => _EnterWifiInfoPageState();
}

class _EnterWifiInfoPageState extends State<EnterWifiInfoPage> {
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Enter Wi-Fi Information")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: ssidController,
              decoration: const InputDecoration(labelText: "Wi-Fi SSID"),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: "Wi-Fi Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                String ssid = ssidController.text;
                String password = passwordController.text;

                if (ssid.isNotEmpty && password.isNotEmpty) {
                  widget.onWifiInfoSubmitted(ssid, password);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text("Please enter both SSID and password.")),
                  );
                }
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }
}
