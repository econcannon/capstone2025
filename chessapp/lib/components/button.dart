import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';

class MyButton extends StatelessWidget {
  final Function()? onPressed;
  final String buttonText;
  const MyButton(
      {super.key, required this.onPressed, required this.buttonText});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(131, 30, 10, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 15, 28, 12),
          height: 50,
          width: 150,
          decoration: BoxDecoration(
            color: HexColor('#44564A'),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(buttonText,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 0,
                color: Colors.white,
              )),
        ),
      ),
    );
  }
}
