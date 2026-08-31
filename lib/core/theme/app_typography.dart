import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Harbor type system: Sora for headings/titles, Work Sans for everything
/// read in the flow of a conversation (body, labels, chat).
class AppTypography {
  AppTypography._();

  static TextTheme textTheme() {
    final display = GoogleFonts.sora();
    final body = GoogleFonts.workSans();

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40, fontWeight: FontWeight.w700, height: 1.1),
      displayMedium: display.copyWith(fontSize: 32, fontWeight: FontWeight.w600, height: 1.15),
      displaySmall: display.copyWith(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2),
      headlineLarge: display.copyWith(fontSize: 24, fontWeight: FontWeight.w600, height: 1.25),
      headlineMedium: display.copyWith(fontSize: 20, fontWeight: FontWeight.w600, height: 1.3),
      headlineSmall: display.copyWith(fontSize: 18, fontWeight: FontWeight.w600, height: 1.3),
      titleLarge: display.copyWith(fontSize: 17, fontWeight: FontWeight.w600, height: 1.3),
      titleMedium: body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
      titleSmall: body.copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
      bodyLarge: body.copyWith(fontSize: 16, fontWeight: FontWeight.w400, height: 1.45),
      bodyMedium: body.copyWith(fontSize: 14, fontWeight: FontWeight.w400, height: 1.45),
      bodySmall: body.copyWith(fontSize: 12.5, fontWeight: FontWeight.w400, height: 1.4),
      labelLarge: body.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2),
      labelMedium: body.copyWith(fontSize: 12, fontWeight: FontWeight.w500, height: 1.2),
      labelSmall: body.copyWith(fontSize: 10.5, fontWeight: FontWeight.w500, height: 1.2),
    );
  }
}
