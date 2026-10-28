import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/client_match.dart';
import '../services/installment_group.dart';
import '../state/app_controller.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/masks.dart';
import '../widgets/amount_keypad.dart';
import '../widgets/common.dart';
import 'add_debt_page.dart';
import 'client_profile_page.dart';
import 'customer_statement_page.dart';
import 'follow_up_page.dart';

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
    final history =
        state.payments.where((item) => ids.contains(item.debtId)).toList()
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
                  '${loans.length} ${loans.length == 1 ? 'lançamento' : 'lançamentos'} na caderneta',
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
          _ActionPair(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        CustomerStatementPage(contactKey: contact.key),
                  ),
                ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Extrato do cliente'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FollowUpPage(
                      contactKey: contact.key,
                      clientName: contact.nome,
                    ),
                  ),
                ),
                icon: const Icon(Icons.event_note_outlined),
                label: const Text('Acompanhar acordo'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const SectionLabel('LANÇAMENTOS'),
          const SizedBox(height: 10),
          ...groupInstallments(loans).map((item) {
            if (item is InstallmentGroup) return _InstallmentCard(group: item);
            final debt = item as Debt;
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
                                    ? 'Vence ${Dates.full(debt.dataVencimento)} · juros ${debt.taxaJuros.toStringAsFixed(debt.taxaJuros == debt.taxaJuros.roundToDouble() ? 0 : 2).replaceAll('.', ',')}%${debt.parcelado ? ' · ${debt.parcelaLabel}' : ''}'
                                    : 'Vence ${Dates.full(debt.dataVencimento)}${debt.parcelado ? ' · ${debt.parcelaLabel}' : ''}',
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
                      const Divider(
                        height: 1,
                        indent: 66,
                        color: Color(0xFFF0F3F8),
                      ),
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
                  payment.estornado
                      ? 'Pagamento estornado'
                      : paymentKindLabel(payment.descricao),
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
              color: payment.estornado
                  ? AppColors.mutedDark
                  : AppColors.success,
              decoration: payment.estornado ? TextDecoration.lineThrough : null,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Duas ações lado a lado; em telas estreitas ou com texto ampliado, empilhadas.
class _ActionPair extends StatelessWidget {
  const _ActionPair({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final stacked =
        MediaQuery.sizeOf(context).width < 360 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.2;
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      );
    }
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

enum _PayChoice { one, two, all, other }

class _InstallmentCard extends StatefulWidget {
  const _InstallmentCard({required this.group});

  final InstallmentGroup group;

  @override
  State<_InstallmentCard> createState() => _InstallmentCardState();
}

class _InstallmentCardState extends State<_InstallmentCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppController>();
    final group = widget.group;
    final abertas = group.abertas(state.saldoOf);
    final atual = abertas.firstOrNull;
    final quitado = atual == null;
    final restante = group.restante(state.saldoOf);
    final pagas = group.pagas(state.saldoOf);
    final atualSaldo = atual == null ? 0.0 : state.saldoOf(atual);
    final parcial = atual != null && atualSaldo < atual.valorAtualizado - 0.009;
    final atrasada = atual != null && atual.isOverdue;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD7E6FF)),
          color: Colors.white,
        ),
        child: Column(
          children: [
            InkWell(
              onTap: quitado ? () => setState(() => _open = !_open) : _pay,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parcelado em ${group.total}x · total ${Money.full(group.valorTotal)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mutedDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quitado
                                ? 'Parcelamento quitado'
                                : Money.full(atual.valorAtualizado),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: quitado
                                  ? AppColors.success
                                  : AppColors.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quitado
                                ? '${group.total} de ${group.total} pagas'
                                : 'Parcela ${atual.parcela} de ${group.total} · vence ${Dates.full(atual.dataVencimento)}${parcial ? ' · falta ${Money.full(atualSaldo)}' : ''}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: atrasada
                                  ? AppColors.danger
                                  : AppColors.mutedDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          quitado ? 'Quitado' : 'Falta ${Money.full(restante)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: quitado ? AppColors.success : AppColors.text,
                          ),
                        ),
                        Text(
                          '$pagas de ${group.total} pagas',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedDark,
                          ),
                        ),
                        if (atrasada)
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pagas / group.total,
                  minHeight: 6,
                  backgroundColor: AppColors.primarySoft,
                  color: AppColors.success,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  if (!quitado)
                    TextButton.icon(
                      onPressed: _pay,
                      icon: const Icon(Icons.payments_outlined, size: 18),
                      label: const Text('Registrar pagamento'),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _open = !_open),
                    child: Text(_open ? 'Ocultar parcelas' : 'Ver parcelas'),
                  ),
                ],
              ),
            ),
            if (_open)
              for (final debt in group.parcelas)
                _InstallmentRow(
                  debt: debt,
                  saldo: state.saldoOf(debt),
                  settled: InstallmentGroup.isSettled(debt, state.saldoOf),
                ),
            if (_open) const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  Future<void> _pay() async {
    final state = context.read<AppController>();
    final group = widget.group;
    final abertas = group.abertas(state.saldoOf);
    if (abertas.isEmpty) return;
    final restante = group.restante(state.saldoOf);
    final first = abertas.first;
    final firstSaldo = state.saldoOf(first);
    final twoSaldo = abertas.length > 2
        ? firstSaldo + state.saldoOf(abertas[1])
        : null;

    final choice = await showModalBottomSheet<_PayChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheet) {
        Widget option(
          IconData icon,
          String title,
          String? value,
          _PayChoice c,
        ) => ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySoft,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            title,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          trailing: value == null
              ? const Icon(Icons.chevron_right_rounded)
              : Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                  ),
                ),
          onTap: () => Navigator.pop(sheet, c),
        );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'O cliente pagou quanto?',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Falta ${Money.full(restante)} em ${abertas.length} ${abertas.length == 1 ? 'parcela' : 'parcelas'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.mutedDark,
                  ),
                ),
                const SizedBox(height: 8),
                option(
                  Icons.looks_one_outlined,
                  'Parcela ${first.parcela} de ${group.total}',
                  Money.full(firstSaldo),
                  _PayChoice.one,
                ),
                if (twoSaldo != null)
                  option(
                    Icons.looks_two_outlined,
                    'As 2 próximas parcelas',
                    Money.full(twoSaldo),
                    _PayChoice.two,
                  ),
                if (abertas.length > 1)
                  option(
                    Icons.done_all_rounded,
                    'Quitar tudo de uma vez',
                    Money.full(restante),
                    _PayChoice.all,
                  ),
                option(
                  Icons.edit_outlined,
                  'Outro valor',
                  null,
                  _PayChoice.other,
                ),
              ],
            ),
          ),
        );
      },
    );
    if (choice == null || !mounted) return;

    final double? valor = switch (choice) {
      _PayChoice.one => firstSaldo,
      _PayChoice.two => twoSaldo,
      _PayChoice.all => restante,
      _PayChoice.other => await showAmountKeypad(
        context: context,
        title: 'Quanto entrou agora?',
        confirmLabel: 'Abater',
        max: restante,
        maxLabel: 'Falta ${Money.full(restante)}',
      ),
    };
    if (valor == null || !mounted) return;

    final controller = context.read<AppController>();
    final plan = planInstallmentPayment(
      abertas: abertas,
      saldoOf: state.saldoOf,
      valor: valor,
    );
    String? error;
    for (final step in plan) {
      error = await controller.abate(debt: step.debt, valor: step.valor);
      if (error != null) break;
    }
    if (!mounted) return;
    final next = group.abertas(controller.saldoOf);
    showPagoSnack(
      context,
      error ??
          (next.isEmpty
              ? 'Parcelamento quitado.'
              : '${Money.full(valor)} recebido. Agora: parcela ${next.first.parcela} de ${group.total}.'),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.debt,
    required this.saldo,
    required this.settled,
  });

  final Debt debt;
  final double saldo;
  final bool settled;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ClientProfilePage(debt: debt)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              settled
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: settled ? AppColors.success : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Parcela ${debt.parcela} de ${debt.totalParcelas} · ${Dates.full(debt.dataVencimento)}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedDark,
                ),
              ),
            ),
            Text(
              settled ? 'Paga' : Money.full(saldo),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                color: settled ? AppColors.success : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
