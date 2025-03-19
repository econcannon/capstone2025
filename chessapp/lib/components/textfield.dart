// ignore_for_file: prefer_typing_uninitialized_variables

import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:google_fonts/google_fonts.dart';

class MyTextField extends StatelessWidget {
  final controller;
  final String hintText;
  final bool obscureText;
  final Icon prefixIcon;
  final Function()? onChanged;

  const MyTextField(
      {super.key,
      required this.controller,
      required this.hintText,
      required this.obscureText,
      required this.prefixIcon,
      this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 332,
        child: TextField(
          controller: controller,
          obscureText: obscureText,
          cursorColor: HexColor("#4f4f4f"),
          decoration: InputDecoration(
            hintText: hintText,
            fillColor: HexColor("#f0f3f1"),
            hintStyle: GoogleFonts.poppins(
              fontSize: 15,
              color: HexColor("#8d8d8d"),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            prefixIcon: prefixIcon,
            prefixIconColor: HexColor("#4f4f4f"),
            filled: true,
          ),
        ));
  }
}
