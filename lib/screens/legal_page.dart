import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../legal/legal_docs.dart';
import '../theme/app_colors.dart';

class LegalPage extends StatelessWidget {
  const LegalPage({super.key, required this.doc});

  final LegalDoc doc;

  static Future<void> open(BuildContext context, LegalDoc doc) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => LegalPage(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = LegalDocs.sectionsOf(doc);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(LegalDocs.titleOf(doc)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            LegalDocs.titleOf(doc),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Última atualização: ${LegalDocs.updatedAt}.',
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.mutedDark,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          for (final section in sections) ...[
            Text(
              section.title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              section.body,
              style: GoogleFonts.plusJakartaSans(
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text(
            'Contato: ${LegalDocs.contact}',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
