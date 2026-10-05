import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../services/client_match.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import 'contact_history_page.dart';

class CadernetaPage extends StatefulWidget {
  const CadernetaPage({super.key});

  @override
  State<CadernetaPage> createState() => _CadernetaPageState();
}

class _CadernetaPageState extends State<CadernetaPage> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final needle = _query.text;
    final contacts = groupContacts(state.debts)
        .where((contact) => contactMatchesQuery(contact, needle))
        .toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Caderneta')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: TextField(
              controller: _query,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar por nome ou telefone',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: needle.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _query.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                contacts.isEmpty
                    ? 'Nenhum contato encontrado.'
                    : '${contacts.length} ${contacts.length == 1 ? 'contato' : 'contatos'}',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.mutedDark,
                ),
              ),
            ),
          ),
          Expanded(
            child: contacts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        state.debts.isEmpty
                            ? 'A caderneta ainda está vazia.'
                            : 'Nada com esse nome ou telefone.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppColors.mutedDark,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                    itemCount: contacts.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final contact = contacts[index];
                      return CadernetaContactTile(
                        contact: contact,
                        saldo: contact.saldoAbertoOf(state.saldoOf),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContactHistoryPage(
                                contactKey: contact.key,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CadernetaContactTile extends StatelessWidget {
  const CadernetaContactTile({
    super.key,
    required this.contact,
    required this.saldo,
    required this.onTap,
    this.padded = true,
  });

  final CadernetaContact contact;
  final double saldo;
  final VoidCallback onTap;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final quitada = !contact.temAberto(state.saldoOf);
    final phone = contact.telefone.trim().isEmpty
        ? 'Sem WhatsApp'
        : formatPhoneBr(contact.telefone);
    final n = contact.lancamentos;
    final extra = n == 1 ? '1 lançamento' : '$n lançamentos';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(padded ? 20 : 0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(padded ? 20 : 0),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: padded
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F3F8)),
                )
              : null,
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  initialsOf(contact.nome),
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.nome,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$phone · $extra',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.mutedDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    quitada ? 'Quitado' : Money.full(saldo),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      color: quitada ? AppColors.success : AppColors.text,
                    ),
                  ),
                  if (!quitada && contact.temAtraso(state.saldoOf))
                    Text(
                      'Em atraso',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
