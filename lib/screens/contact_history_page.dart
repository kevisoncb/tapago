import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import '../widgets/common.dart';
import 'add_debt_page.dart';
import 'client_profile_page.dart';

class ContactHistoryPage extends StatelessWidget {
  const ContactHistoryPage({super.key, required this.contactKey});

  final String contactKey;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final contact = groupContacts(state.debts)
        .where((item) => item.key == contactKey)
        .firstOrNull;

    if (contact == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(title: const Text('Contato')),
        body: Center(
          child: Text(
            'Este contato não está mais na caderneta.',
            style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
          ),
        ),
      );
    }

    final saldo = contact.saldoAbertoOf(state.saldoOf);
    final quitado = !contact.temAberto(state.saldoOf);
    final ids = contact.debts.map((debt) => debt.id).toSet();
    final history = state.payments.where((item) => ids.contains(item.debtId)).toList()
      ..sort((a, b) => b.data.compareTo(a.data));
    final loans = [...contact.debts]
      ..sort((a, b) => b.dataVencimento.compareTo(a.dataVencimento));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Contato'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: AppColors.primarySoft,
              child: Text(
                initialsOf(contact.nome),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            contact.nome,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            contact.telefone.trim().isEmpty
                ? 'Sem WhatsApp'
                : formatPhoneBr(contact.telefone),
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedDark,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: quitado ? AppColors.successSoft : AppColors.primarySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Text(
                  quitado ? 'Tudo quitado' : Money.full(saldo),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: quitado ? AppColors.success : AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${loans.length} ${loans.length == 1 ? 'empréstimo' : 'empréstimos'} na caderneta',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddDebtPage(
                      prefillNome: contact.nome,
                      prefillTelefone: contact.telefone,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo lançamento'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: Color(0xFFD7E6FF)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          const SectionLabel('EMPRÉSTIMOS'),
          const SizedBox(height: 10),
          ...loans.map((debt) {
            final itemSaldo = state.saldoOf(debt);
            final itemQuitado = debt.statusPago || itemSaldo <= 0.009;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ClientProfilePage(debt: debt),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF0F3F8)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                Money.full(debt.valorAtualizado),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                debt.taxaJuros > 0
                                    ? 'Vence ${Dates.full(debt.dataVencimento)} · juros ${debt.taxaJuros.toStringAsFixed(debt.taxaJuros == debt.taxaJuros.roundToDouble() ? 0 : 2).replaceAll('.', ',')}%'
                                    : 'Vence ${Dates.full(debt.dataVencimento)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.mutedDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              itemQuitado ? 'Quitado' : Money.full(itemSaldo),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                color: itemQuitado
                                    ? AppColors.success
                                    : AppColors.text,
                              ),
                            ),
                            if (!itemQuitado && debt.isOverdue)
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
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          const SectionLabel('HISTÓRICO'),
          const SizedBox(height: 10),
          if (history.isEmpty)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0F3F8)),
              ),
              child: Text(
                'Ainda não teve abatimento nesta pessoa.',
                style: GoogleFonts.plusJakartaSans(color: AppColors.mutedDark),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFF0F3F8)),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < history.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, indent: 66, color: Color(0xFFF0F3F8)),
                    _HistoryRow(
                      payment: history[i],
                      debt: loans
                          .where((debt) => debt.id == history[i].debtId)
                          .firstOrNull,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.payment, this.debt});

  final Payment payment;
  final Debt? debt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paymentKindLabel(payment.descricao),
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  [
                    if (debt != null) Money.full(debt!.valorAtualizado),
                    Dates.history(payment.data),
                  ].join(' · '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppColors.mutedDark,
                  ),
                ),
              ],
            ),
          ),
          Text(
            Money.full(payment.valor),
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
