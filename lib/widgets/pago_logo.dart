import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/constants.dart';

class PagoMark extends StatelessWidget {
  const PagoMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.23),
      child: Image.asset(
        AppConstants.logoAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}

class PagoWordmark extends StatelessWidget {
  const PagoWordmark({
    super.key,
    this.markSize = 36,
    this.fontSize = 26,
  });

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PagoMark(size: markSize),
        SizedBox(width: markSize * 0.28),
        Text(
          '${AppConstants.appName}!',
          style: GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
      ],
    );
  }
}
