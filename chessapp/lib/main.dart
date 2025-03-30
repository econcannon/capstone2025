// Flutter package imports
import 'package:flutter/material.dart';

// Third-party package imports
import 'package:hexcolor/hexcolor.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

// Project imports
import 'package:chessapp/authentication/login.dart';



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
