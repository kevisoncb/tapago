import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class WhatsAppMark extends StatelessWidget {
  const WhatsAppMark({super.key, this.size = 36});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.whatsapp,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.chat_rounded,
        color: Colors.white,
        size: size * 0.52,
      ),
    );
  }
}
